#!/usr/bin/env bash
# Shared config loader for the prod-* scripts. Sourced, not executed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/prod.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy scripts/prod.env.example and fill it in." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${JACKED_URL:?JACKED_URL must be set in scripts/prod.env}"
: "${JACKED_API_KEY:?JACKED_API_KEY must be set in scripts/prod.env}"

api() {
  # api <method> <path> — authenticated curl against the prod server.
  local method="$1" path="$2"
  curl -sS -X "$method" -H "Authorization: Bearer $JACKED_API_KEY" "$JACKED_URL$path"
}

require_ssh() {
  if [[ -z "${JACKED_SSH_HOST:-}" ]]; then
    echo "JACKED_SSH_HOST is not set in scripts/prod.env — this command needs SSH access." >&2
    exit 1
  fi
}
