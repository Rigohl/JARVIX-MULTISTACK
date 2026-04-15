# JARVIX Deployment (POC)

This doc shows a minimal POC flow using Supabase or Neon (Postgres) and Helm.

## Prereqs

- Kubernetes cluster (minikube / k3s / cloud)
- Helm 3
- Docker or registry to push images
- Supabase or Neon project (get DATABASE_URL)

## Build image (example)

```
./scripts/docker-build.sh latest
docker push <your-repo>/jarvix-engine:latest
```

## Install with Helm

```bash
helm install jarvix deploy/helm/jarvix \
  --set image.repository=<your-repo>/jarvix-engine \
  --set image.tag=latest \
  --set env.DB_URL="$DATABASE_URL" \
  --set env.SUPABASE_URL="$SUPABASE_URL" \
  --set env.SUPABASE_KEY="$SUPABASE_KEY"
```

## Migrate SQLite metrics to Postgres

```
# from repo root
bash scripts/migrate_sqlite_to_postgres.sh data/metrics.sqlite "$DATABASE_URL"
```

Notes:

- The migration script imports all columns as TEXT (POC). Review and apply proper types after migration.
- For Supabase: use the dashboard to get `DATABASE_URL`. For Neon: use console.
- For production consider proper backups, TLS and secrets in Kubernetes (use sealed-secrets or external secret stores).

## Docker credentials → GitHub secrets

If you want CI to push images to Docker Hub automatically, create these repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

You can extract your Docker Hub credentials locally then upload them manually, or use the provided helper script.

### Extract and upload automatically (recommended for POC)

1. Requirements: `jq`, GitHub CLI `gh` (authenticated), and Docker logged-in locally.
2. Run (in repo root):

```bash
# dry-run: shows username only
./scripts/export_docker_to_github_secrets.sh --dry-run

# interactive: will prompt before setting secrets
./scripts/export_docker_to_github_secrets.sh --repo OWNER/REPO

# non-interactive (be careful!)
./scripts/export_docker_to_github_secrets.sh --repo OWNER/REPO --yes
```

### Create token via UI and set from clipboard (recommended, secure)

1. In your browser open: <https://hub.docker.com/settings/security>
2. Create a new Access Token (give it a name like `jarvix-ci`) and copy the token value.
3. On Windows, run (from repo root):

```powershell
.\scripts\set_dockerhub_token_from_clipboard.ps1
```

The script reads the token from the clipboard and sets the secret `DOCKERHUB_TOKEN` (and optionally `DOCKERHUB_USERNAME`) using `gh`; it does not print the token.

1. On macOS/Linux, run:

```bash
./scripts/set_dockerhub_token_from_clipboard.sh
```

### Automated creation via Playwright (advanced)

If you want the creation to be automated (the script logs into Docker Hub, creates a token, and uploads it to GitHub Secrets), use the Playwright helper. This requires Node.js and Playwright installed and either:

- a persistent browser profile that is already logged into Docker Hub (pass `--profile <dir>`), or
- provide credentials via environment variables `DOCKERHUB_USER` and `DOCKERHUB_PASSWORD`.

Run (from repo root):

```bash
# install Playwright browsers (first time)
npm i -D playwright
npx playwright install

# example (interactive login, Windows PowerShell wrapper)
.\scripts\create_dockerhub_token_playwright.ps1 -Repo "Rigohl/JARVIX-MULTISTACK"

# or directly (env vars)
DOCKERHUB_USER=you DOCKERHUB_PASSWORD=pass GITHUB_REPO=Rigohl/JARVIX-MULTISTACK node scripts/create_dockerhub_token_playwright.js --token-name "jarvix-ci-$(date +%F)"
```

Security notes:

- The script detects 2FA and will abort; in that case create the token manually via the UI.
- The script never prints the token; it sets it with `gh secret set` via stdin.

### Extract manually (if you prefer)

- Linux / macOS:

```bash
jq -r '.auths["https://index.docker.io/v1/"].auth' ~/.docker/config.json | base64 --decode
# output: username:token
```

- PowerShell (Windows):

```powershell
$cfg = Get-Content $env:USERPROFILE + '\.docker\config.json' -Raw | ConvertFrom-Json
$auth = $cfg.auths.'https://index.docker.io/v1/'.auth
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($auth))
# output: username:token
```

Then add secrets via GitHub UI (Settings → Secrets → Actions → New repository secret) or using `gh`:

```bash
gh secret set DOCKERHUB_USERNAME -b"yourusername" --repo OWNER/REPO
gh secret set DOCKERHUB_TOKEN -b"yourtoken" --repo OWNER/REPO
```

**Security note:** Do not commit your tokens to the repo. Use GitHub Secrets and rotate the token after use.
