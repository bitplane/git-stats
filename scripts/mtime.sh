#!/bin/bash
# scripts/mtime.sh
# Updates local file mtimes to match their last commit date.
# Skips any file that has local modifications.

set -euo pipefail

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "Error: Not a git repository (or any of the parent directories)"
  exit 1
fi

cd "$TARGET_DIR"

CHANGED_FILES=$(git status --porcelain | grep -v "??" | awk '{print $2}' || echo "")

if [ -n "$CHANGED_FILES" ]; then
  echo "ℹ️  Found uncommitted changes - skipping these files:"
  echo "$CHANGED_FILES" | sed 's/^/  - /'
  echo "Proceeding with unchanged files only..."
fi

git ls-files | while read -r file; do
  [ -f "$file" ] || continue
  if echo "$CHANGED_FILES" | grep -q "^$file$"; then
    echo "Skipping (has local changes): $file"
    continue
  fi
  timestamp=$(git log -1 --format="%at" -- "$file" || true)
  if [ -n "$timestamp" ]; then
    touch -m -t "$(date -d "@$timestamp" "+%Y%m%d%H%M.%S")" "$file"
    echo "Updated: $file → $(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")"
  else
    echo "Warning: No commits for $file ?"
  fi
done

echo "✅ File modification times updated."
exit 0
