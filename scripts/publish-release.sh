#!/usr/bin/env bash
set -euo pipefail

EXTENSION="${EXTENSION:-}"
DRY_RUN="${DRY_RUN:-0}"
R2_BUCKET="${R2_BUCKET:-}"
R2_ENDPOINT="${R2_ENDPOINT:-}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"

if [[ "$DRY_RUN" != "0" && "$DRY_RUN" != "1" ]]; then
    echo "Error: DRY_RUN must be 0 or 1" >&2
    exit 1
fi

if [[ "$DRY_RUN" == "0" ]]; then
    [[ -n "$R2_BUCKET" ]] || { echo "Error: R2_BUCKET is not configured" >&2; exit 1; }
    [[ -n "$R2_ENDPOINT" ]] || { echo "Error: R2_ENDPOINT is not configured" >&2; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is not installed" >&2; exit 1; }
fi

upload_list=$(python3 scripts/verify-release.py --list "$EXTENSION")
mapfile -t uploads <<< "$upload_list"

for entry in "${uploads[@]}"; do
    IFS=$'\t' read -r policy source object_key <<< "$entry"
    if [[ "$policy" == "immutable" ]]; then
        cache_control="public, max-age=31536000, immutable"
    else
        cache_control="no-cache, no-store, must-revalidate"
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "Would upload: ${source} -> s3://${R2_BUCKET:-<bucket>}/${object_key}"
    else
        aws s3 cp "$source" "s3://${R2_BUCKET}/${object_key}" \
            --endpoint-url "$R2_ENDPOINT" \
            --cache-control "$cache_control" \
            --only-show-errors
        echo "Published: ${object_key}"
    fi
done

if [[ "$DRY_RUN" == "1" ]]; then
    echo "Dry run completed: no files uploaded"
else
    echo "Release published successfully"
fi
