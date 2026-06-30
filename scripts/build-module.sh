#!/usr/bin/env bash
set -e

MODULE="$1"

if [ -z "$MODULE" ]; then
    echo "Error: missing module name"
    echo "Usage: $0 <module_name>"
    exit 1
fi

SRC_DIR="repos/modules/${MODULE}"

if [ ! -d "$SRC_DIR" ]; then
    echo "Error: module directory not found: ${SRC_DIR}"
    exit 1
fi

MANIFEST="${SRC_DIR}/${MODULE}.xml"

if [ ! -f "$MANIFEST" ]; then
    echo "Error: manifest not found: ${MANIFEST}"
    exit 1
fi

VERSION=$(grep -oP '<version>\K[^<]+' "$MANIFEST" | head -1 || true)

if [ -z "$VERSION" ]; then
    VERSION="dev"
fi

OUT_DIR="build/releases"
mkdir -p "$OUT_DIR"

ZIP_FILE="${OUT_DIR}/${MODULE}_${VERSION}.zip"

python3 -c "
import os, zipfile

src = os.path.abspath('${SRC_DIR}')
out = os.path.abspath('${ZIP_FILE}')

exclude_patterns = {
    '.git', '.gitignore', '.idea', '.DS_Store',
    'node_modules', 'vendor',
}

exclude_suffixes = {'.log', '.md'}
exclude_dirs = {'test', 'tests', '__pycache__'}

with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        if rel == '.':
            rel = ''

        # Skip excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_patterns and d not in exclude_dirs]

        for f in files:
            if f in exclude_patterns:
                continue
            if any(f.endswith(s) for s in exclude_suffixes):
                continue
            arcname = os.path.join(rel, f) if rel else f
            zf.write(os.path.join(root, f), arcname)
"

echo "Release created: ${ZIP_FILE}"
