#!/usr/bin/env bash
#
# Local secret-scanning fallback. CI uses the Gitleaks action with full history.
# This script prefers the Gitleaks CLI when available and falls back to a small
# high-signal grep check for local development.
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if command -v gitleaks >/dev/null 2>&1; then
  exec gitleaks detect --source . --redact --verbose
fi

echo "gitleaks not installed; running fallback grep scan."
echo "Install the Gitleaks CLI for a full history scan: https://github.com/gitleaks/gitleaks"

pattern='AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{20,}'

if grep -RInE \
  --exclude-dir=.git \
  --exclude-dir=.terraform \
  --exclude='*.tfstate*' \
  --exclude='*.tgz' \
  --exclude='*.zip' \
  "${pattern}" .; then
  echo "Potential secret material found." >&2
  exit 1
fi

echo "No obvious secret material found."
