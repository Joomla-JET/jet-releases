#!/usr/bin/env bash
set -euo pipefail

EXTENSION="${EXTENSION:-${1:-}}"
DRY_RUN="${DRY_RUN:-0}"
PAGES_REMOTE="${PAGES_REMOTE:-releases}"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"

if [[ "$DRY_RUN" != "0" && "$DRY_RUN" != "1" ]]; then
    echo "Error: DRY_RUN must be 0 or 1" >&2
    exit 1
fi

upload_list=$(python3 scripts/verify-release.py --list "$EXTENSION")
mapfile -t uploads <<< "$upload_list"

if [[ "$DRY_RUN" == "1" ]]; then
    for entry in "${uploads[@]}"; do
        IFS=$'\t' read -r _ source object_key <<< "$entry"
        echo "Would publish: ${source} -> ${PAGES_REMOTE}/${PAGES_BRANCH}:${object_key}"
    done
    echo "Dry run completed: no files published"
    exit 0
fi

git remote get-url "$PAGES_REMOTE" >/dev/null 2>&1 || {
    echo "Error: Git remote not found: ${PAGES_REMOTE}" >&2
    exit 1
}

worktree=$(mktemp -d "${TMPDIR:-/tmp}/jet-pages.XXXXXX")
cleanup() {
    git worktree remove --force "$worktree" >/dev/null 2>&1 || true
    rmdir "$worktree" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if git ls-remote --exit-code --heads "$PAGES_REMOTE" "$PAGES_BRANCH" >/dev/null 2>&1; then
    git fetch "$PAGES_REMOTE" "$PAGES_BRANCH"
    git worktree add --detach "$worktree" FETCH_HEAD >/dev/null
else
    git worktree add --detach "$worktree" HEAD >/dev/null
    git -C "$worktree" rm -rf --ignore-unmatch . >/dev/null
fi

for entry in "${uploads[@]}"; do
    IFS=$'\t' read -r policy source object_key <<< "$entry"
    destination="$worktree/$object_key"
    mkdir -p "$(dirname "$destination")"
    if [[ "$policy" == "immutable" && -f "$destination" ]] && ! cmp -s "$source" "$destination"; then
        echo "Error: refusing to overwrite published artifact with different content: ${object_key}" >&2
        echo "Increment the extension version and build again." >&2
        exit 1
    fi
    cp "$source" "$destination"
done

touch "$worktree/.nojekyll"
printf '* -text\n' > "$worktree/.gitattributes"
git -C "$worktree" -c core.autocrlf=false add .
if git -C "$worktree" diff --cached --quiet; then
    echo "Nothing to publish: GitHub Pages is already up to date"
    exit 0
fi

selection="${EXTENSION:-all extensions}"
git -C "$worktree" commit -m "Publish ${selection}" >/dev/null
git -C "$worktree" push "$PAGES_REMOTE" "HEAD:refs/heads/${PAGES_BRANCH}"
echo "Release published successfully to ${PAGES_REMOTE}/${PAGES_BRANCH}"
