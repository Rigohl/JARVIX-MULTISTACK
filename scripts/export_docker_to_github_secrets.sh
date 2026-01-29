#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/export_docker_to_github_secrets.sh [--repo owner/repo] [--prefix DOCKERHUB] [--yes] [--dry-run]

Extract Docker Hub auth from local ~/.docker/config.json and set GitHub repository secrets via 'gh'.

Options:
  --repo <owner/repo>   GitHub repository to set secrets (default: inferred from git remote)
  --prefix <PREFIX>     Secret name prefix (default: DOCKERHUB)
  --dry-run             Print what would be set (username only); do not set secrets
  --yes                 Non-interactive; proceed without prompts
  -h, --help            Show this help

Requirements:
  - 'jq' to parse JSON
  - 'gh' (GitHub CLI) authenticated with appropriate repo permissions
  - Local Docker config with auth (usually at ~/.docker/config.json)

This script is a convenience helper for POC only. It will NOT print or expose tokens in logs by default.
EOF
}

REPO=""
PREFIX="DOCKERHUB"
DRY_RUN=0
YES=0

while (("$#")); do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

# infer repo from git remote if possible
if [ -z "$REPO" ]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    origin_url=$(git remote get-url origin 2>/dev/null || true)
    if [ -n "$origin_url" ]; then
      # supports git@github.com:owner/repo.git and https://github.com/owner/repo.git
      REPO=$(echo "$origin_url" | sed -E 's#.*[:/](.+/.+?)(\.git)?$#\1#')
    fi
  fi
fi

if [ -z "$REPO" ]; then
  echo "ERROR: Could not determine GitHub repo. Provide --repo owner/repo"
  exit 1
fi

DOCKER_CONFIG=${DOCKER_CONFIG:-"$HOME/.docker/config.json"}
if [ ! -f "$DOCKER_CONFIG" ]; then
  # On Windows (PowerShell), try the default Windows path
  if [ -n "${USERPROFILE:-}" ] && [ -f "$USERPROFILE/.docker/config.json" ]; then
    DOCKER_CONFIG="$USERPROFILE/.docker/config.json"
  else
    echo "ERROR: Docker config not found at $DOCKER_CONFIG"
    exit 1
  fi
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: 'jq' is required but not installed. Install jq and retry."
  exit 1
fi

# Try to extract the auth token for Docker Hub (index.docker.io)
auth=$(jq -r '(.auths["https://index.docker.io/v1/"].auth) // ( .auths | to_entries[0].value.auth )' "$DOCKER_CONFIG" 2>/dev/null || true)

if [ -z "$auth" ] || [ "$auth" == "null" ]; then
  echo "ERROR: No auth entry found in $DOCKER_CONFIG"
  exit 1
fi

# base64 decode
decoded=$(echo "$auth" | base64 --decode 2>/dev/null || echo "$auth" | base64 -d 2>/dev/null || true)
if [ -z "$decoded" ]; then
  echo "ERROR: Failed to decode auth entry from $DOCKER_CONFIG"
  exit 1
fi

username=$(echo "$decoded" | awk -F: '{print $1}')
token=$(echo "$decoded" | awk -F: '{ $1=""; sub(/^:/,""); print $0 }')

if [ -z "$username" ] || [ -z "$token" ]; then
  echo "ERROR: Could not parse username/token from decoded auth (expected format 'username:password_or_token')."
  exit 1
fi

echo "Found Docker username: $username"

if [ $DRY_RUN -eq 1 ]; then
  echo "DRY RUN: Would set secrets in repo $REPO: ${PREFIX}_USERNAME -> $username ; ${PREFIX}_TOKEN -> <hidden>"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: 'gh' (GitHub CLI) is required to set repo secrets. Install gh and authenticate (gh auth login)."
  exit 1
fi

if [ $YES -ne 1 ]; then
  read -r -p "Proceed to set secrets in GitHub repo '$REPO'? (y/N) " ans
  case "$ans" in
    y|Y) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

set +x
# use gh to set secrets; keep token hidden
echo -n "$username" | gh secret set "${PREFIX}_USERNAME" -R "$REPO" -b - >/dev/null
echo -n "$token" | gh secret set "${PREFIX}_TOKEN" -R "$REPO" -b - >/dev/null
set -x

echo "Done. Secrets set: ${PREFIX}_USERNAME and ${PREFIX}_TOKEN on $REPO"

echo "Note: This helper is POC-only. Review secrets in GitHub settings and consider rotating tokens after use."
