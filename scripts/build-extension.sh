#!/usr/bin/env bash
set -euo pipefail

TYPE="${1:-}"
EXTENSION="${2:-}"
BASE_URL="${BASE_URL:-https://joomla-jet.github.io/jet-releases}"

if [[ -z "$TYPE" || -z "$EXTENSION" ]]; then
    echo "Usage: $0 <modules|components|templates> <extension_name>" >&2
    exit 1
fi

python3 scripts/package-extension.py "$TYPE" "$EXTENSION" "$BASE_URL"
