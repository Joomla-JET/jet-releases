#!/usr/bin/env bash
set -euo pipefail

EXTENSION="${1:-}"
EXTENSION_GROUPS=(modules components templates)

build_one() {
    local group="$1"
    local extension="$2"
    bash scripts/build-extension.sh "$group" "$extension"
}

if [[ -n "$EXTENSION" ]]; then
    matches=()
    for group in "${EXTENSION_GROUPS[@]}"; do
        [[ -d "repos/${group}/${EXTENSION}" ]] && matches+=("$group")
    done

    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "Error: extension not found: ${EXTENSION}" >&2
        exit 1
    fi
    if [[ ${#matches[@]} -gt 1 ]]; then
        echo "Error: extension name is ambiguous: ${EXTENSION}" >&2
        exit 1
    fi

    build_one "${matches[0]}" "$EXTENSION"
    exit 0
fi

found=0
for group in "${EXTENSION_GROUPS[@]}"; do
    for directory in "repos/${group}"/*/; do
        [[ -d "$directory" ]] || continue
        found=1
        build_one "$group" "$(basename "$directory")"
    done
done

if [[ $found -eq 0 ]]; then
    echo "Error: no extensions found under repos/" >&2
    exit 1
fi
