#!/usr/bin/env node
/**
 * create_dockerhub_token_playwright.js
 *
 * Usage:
 *  - Environment variables (recommended):
 *      DOCKERHUB_USER, DOCKERHUB_PASSWORD, GITHUB_REPO (default: Rigohl/JARVIX-MULTISTACK)
 *  - Options:
 *      --token-name <name>    (default: jarvix-ci-YYYYMMDD)
 *      --headless             (run headless)
 *      --profile <dir>        (use Playwright persistent profile to reuse logged-in session)
 *      --dry-run              (don't set GitHub secret, just print actions)
 *
 * Notes:
 *  - Requires: Node.js and the `playwright` package installed (npm i -D playwright)
 *  - Requires: gh (GitHub CLI) installed and authenticated
 *  - The script will not print secrets. If 2FA is detected, it will abort and instruct.
 */

const cp = require('child_process')
const fs = require('fs')
const path = require('path')

function exitError(msg, code = 1) {
  console.error('ERROR:', msg)
  process.exit(code)
}

function parseArgs() {
  const argv = process.argv.slice(2)
  const opts = {}
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--token-name') { opts.tokenName = argv[++i] }
    else if (a === '--headless') { opts.headless = true }
    else if (a === '--profile') { opts.profile = argv[++i] }
    else if (a === '--dry-run') { opts.dryRun = true }
    else if (a === '--help' || a === '-h') { opts.help = true }
    else {
      // ignore unknown
    }
  }
  return opts
}

(async () => {
  const opts = parseArgs()
  if (opts.help) {
    console.log('Usage: node scripts/create_dockerhub_token_playwright.js --token-name "name" [--headless] [--profile <dir>] [--dry-run]')
    process.exit(0)
  }

  const repo = process.env.GITHUB_REPO || 'Rigohl/JARVIX-MULTISTACK'
  const username = process.env.DOCKERHUB_USER || process.env.DOCKERHUB_USERNAME
  const password = process.env.DOCKERHUB_PASSWORD || process.env.DOCKERHUB_PASS
  const tokenName = opts.tokenName || `jarvix-ci-${(new Date()).toISOString().slice(0,10)}`
  const dryRun = !!opts.dryRun

  // check gh
  try {
    cp.spawnSync('gh', ['auth', 'status'], { stdio: 'ignore' })
  } catch (e) {
    exitError('GitHub CLI `gh` not found or not authenticated. Install and run `gh auth login`.', 10)
  }

  // require playwright dynamically
  let playwright
  try {
    playwright = require('playwright')
  } catch (e) {
    exitError('Playwright not installed. Run `npm i -D playwright` and `npx playwright install`.', 20)
  }

  const { chromium } = playwright
  let browser, context
  try {
    if (opts.profile) {
      const profileDir = path.resolve(opts.profile)
      console.log('Using persistent profile:', profileDir)
      context = await chromium.launchPersistentContext(profileDir, { headless: !!opts.headless })
    } else {
      browser = await chromium.launch({ headless: !!opts.headless })
      context = await browser.newContext()
    }

    const page = await context.newPage()

    // go to security page
    await page.goto('https://hub.docker.com/settings/security', { waitUntil: 'networkidle' })

    // detect if login page shown
    const signInDetected = await page.locator('text=Sign in').count() > 0 || await page.title().then(t => t && /sign in/i.test(t))
    if (signInDetected) {
      console.log('Login required on Docker Hub.')
      if (!username || !password) {
        if (opts.profile) {
          // with persistent profile we expected to be logged in
          console.log('Using persistent profile but still required to sign in. Please ensure the profile dir is an active logged-in browser profile.')
        }
        exitError('No credentials provided (set DOCKERHUB_USER and DOCKERHUB_PASSWORD env vars) or use a persistent profile.', 30)
      }

      // fill username/email
      const userSelectorCandidates = ['input[placeholder="Username or email address"]', 'input[type="email"]', 'input[name="username"]']
      let userSel = null
      for (const s of userSelectorCandidates) {
        if (await page.locator(s).count() > 0) { userSel = s; break }
      }
      if (!userSel) exitError('Could not find username/email input on Docker login page.', 31)
      await page.fill(userSel, username)
      // click continue/next
      const continueBtn = ['button:has-text("Continue")', 'button:has-text("Sign in")', 'button:has-text("Log in")']
      let clicked = false
      for (const b of continueBtn) {
        if (await page.locator(b).count() > 0) { await page.locator(b).first().click(); clicked = true; break }
      }
      if (!clicked) {
        // try submit on form
        await page.keyboard.press('Enter')
      }

      // wait for password input
      await page.waitForTimeout(1000)
      const pwdSelCandidates = ['input[type="password"]', 'input[name="password"]']
      let pwdSel = null
      for (const s of pwdSelCandidates) {
        if (await page.locator(s).count() > 0) { pwdSel = s; break }
      }
      if (!pwdSel) exitError('Could not find password input after username step. SSO / alternate flow detected; aborting.', 32)
      await page.fill(pwdSel, password)
      // click sign in
      const signBtns = ['button:has-text("Sign in")', 'button:has-text("Continue")', 'button:has-text("Log in")']
      for (const b of signBtns) {
        if (await page.locator(b).count() > 0) { await page.locator(b).first().click(); break }
      }

      // wait for navigation or 2FA
      await page.waitForLoadState('networkidle')

      // detect 2FA
      const twoFaPresent = await page.locator('input[placeholder*="authentication code"], input[name="otp"], text=Two-factor').count() > 0
      if (twoFaPresent) {
        exitError('Two-factor authentication (2FA) detected. Cannot complete automated token creation. Please create the token manually or disable 2FA temporarily.', 33)
      }

    }

    // ensure we're on the security page now
    await page.goto('https://hub.docker.com/settings/security', { waitUntil: 'networkidle' })

    // find create token button
    const createSelectors = [
      'button:has-text("Create Access Token")',
      'button:has-text("Create Token")',
      'button:has-text("New Access Token")',
      'text=New Access Token'
    ]
    let createFound = false
    for (const s of createSelectors) {
      if (await page.locator(s).count() > 0) { await page.locator(s).first().click(); createFound = true; break }
    }
    if (!createFound) exitError('Could not find "Create Access Token" button on the Security settings page. UI may have changed.', 40)

    // wait for dialog and token name input
    await page.waitForTimeout(700)
    // attempt a few ways to set token name
    const nameInputCandidates = [
      'input[placeholder*="Name"]',
      'input[name*="name"]',
      'form input'
    ]
    let nameSet = false
    for (const sel of nameInputCandidates) {
      try {
        const cnt = await page.locator(sel).count()
        if (cnt > 0) {
          await page.locator(sel).first().fill(tokenName)
          nameSet = true
          break
        }
      } catch (e) { }
    }
    if (!nameSet) {
      // maybe modal has a simple text input in another place - try to type
      await page.keyboard.type(tokenName)
    }

    // click confirm/create in modal
    const confirmButtons = ['button:has-text("Create")', 'button:has-text("Generate")', 'button:has-text("Create Token")']
    let confirmed = false
    for (const b of confirmButtons) {
      if (await page.locator(b).count() > 0) { await page.locator(b).first().click(); confirmed = true; break }
    }
    if (!confirmed) {
      // try pressing Enter
      await page.keyboard.press('Enter')
    }

    // wait for result -> token text visible in a readonly input/textarea or a copy button
    await page.waitForTimeout(700)

    // attempt to read the token value
    let token = null
    const tokenSelectors = [
      'div[role="dialog"] input[readonly]',
      'div[role="dialog"] textarea',
      'input[readonly]',
      'textarea[readonly]',
      'input[type="text"][aria-readonly="true"]'
    ]
    for (const sel of tokenSelectors) {
      try {
        if (await page.locator(sel).count() > 0) {
          // get value property
          token = await page.locator(sel).first().evaluate(el => el.value || el.textContent || '')
          token = (token || '').trim()
          if (token) break
        }
      } catch (e) { }
    }

    // fallback: look for a copy button and read its data-clipboard-text
    if (!token) {
      const copyButton = await page.locator('button:has-text("Copy"), button[aria-label*="Copy"]').first()
      if (copyButton && await copyButton.count() > 0) {
        try {
          const data = await copyButton.evaluate(b => b.getAttribute('data-clipboard-text') || '')
          if (data) token = data.trim()
        } catch (e) {}
      }
    }

    if (!token) {
      exitError('Failed to extract token text from the UI. UI may have changed or token not displayed; create it manually.', 50)
    }

    // token obtained - set GitHub secret unless dry-run
    if (dryRun) {
      console.log('Dry-run: token captured (not printed) and would be set for repo:', repo)
    } else {
      // set DOCKERHUB_TOKEN securely via gh
      const setProc = cp.spawnSync('gh', ['secret', 'set', 'DOCKERHUB_TOKEN', '-R', repo, '-b', '-'], { input: token, encoding: 'utf-8' })
      if (setProc.status !== 0) {
        console.error(setProc.stderr || setProc.stdout || 'gh secret set failed')
        exitError('Setting DOCKERHUB_TOKEN failed via gh. Ensure gh is authenticated and you have repo admin permission.', 60)
      }
      // set username secret if provided / needed
      if (username) {
        const setUser = cp.spawnSync('gh', ['secret', 'set', 'DOCKERHUB_USERNAME', '-R', repo, '-b', '-'], { input: username, encoding: 'utf-8' })
        if (setUser.status !== 0) {
          console.warn('Warning: setting DOCKERHUB_USERNAME failed (continuing).')
        }
      }
      console.log('SECRETS_SET')
    }

    // cleanup
    if (browser) await browser.close()
    else await context.close()

    process.exit(0)

  } catch (err) {
    if (err && err.message) {
      console.error('ERROR:', err.message)
      console.error(err.stack || '')
    } else {
      console.error(err)
    }
    try { if (browser) await browser.close(); else if (context) await context.close() } catch (e) {}
    process.exit(99)
  }
})()
