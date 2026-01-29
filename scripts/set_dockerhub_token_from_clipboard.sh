#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-Rigohl/JARVIX-MULTISTACK}"

if ! command -v gh >/dev/null 2>&1; then
  echo "'gh' not found in PATH. Install GitHub CLI and authenticate first (gh auth login)." >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh not authenticated. Run 'gh auth login' and try again." >&2
  exit 2
fi

TOKEN=""
if command -v pbpaste >/dev/null 2>&1; then
  TOKEN="$(pbpaste)"
elif command -v xclip >/dev/null 2>&1; then
  TOKEN="$(xclip -selection clipboard -o)"
elif command -v wl-paste >/dev/null 2>&1; then
  TOKEN="$(wl-paste)"
else
  echo "No clipboard utility found (pbpaste, xclip or wl-paste). Copy token and run: printf '%s' \"TOKEN\" | gh secret set DOCKERHUB_TOKEN -R $REPO -b -" >&2
  exit 3
fi

if [ -z "$TOKEN" ] || [ ${#TOKEN} -lt 10 ]; then
  echo "Clipboard doesn't look like a token. Copy your token and try again." >&2
  exit 4
fi

printf '%s' "$TOKEN" | gh secret set DOCKERHUB_TOKEN -R "$REPO" -b -
echo "DOCKERHUB_TOKEN set for $REPO"

# Optionally ask for username if missing
if ! gh secret list -R "$REPO" --json name -q '.[] | .name' | grep -q DOCKERHUB_USERNAME; then
  read -p "No DOCKERHUB_USERNAME found. Enter Docker Hub username to set as DOCKERHUB_USERNAME (or press Enter to skip): " username
  if [ -n "$username" ]; then
    printf '%s' "$username" | gh secret set DOCKERHUB_USERNAME -R "$REPO" -b -
    echo "DOCKERHUB_USERNAME set"
  fi
fi
