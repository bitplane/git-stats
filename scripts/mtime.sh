#!/bin/bash
# mtime.sh
# Updates the modification time of each file to match its last commit time
# Skips files with uncommitted changes
# Usage: ./mtime.sh [directory]

set -euo pipefail

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "Error: Not a git repository (or any of the parent directories)"
  exit 1
fi

cd "$TARGET_DIR"

# Skip Makefile when run from make or if explicitly stated
# More reliable detection of running under make
if [ -n "${MAKE+x}" ] || [ -n "${MAKEFLAGS+x}" ] || [ -n "${MAKELEVEL+x}" ] || ps -o ppid= $ | xargs ps -o comm= | grep -q make; then
  SKIP_FILES="Makefile"
  echo "Running from make, will skip Makefile"
else
  SKIP_FILES=""
fi

# Get list of files with uncommitted changes
CHANGED_FILES=$(git status --porcelain | grep -v "??" | awk '{print $2}' || echo "")

# If there are changed files, inform the user but continue
if [ -n "$CHANGED_FILES" ]; then
  echo "ℹ️ Found uncommitted changes - skipping these files:"
  echo "$CHANGED_FILES" | sed 's/^/  - /'
  echo "Proceeding with unchanged files only..."
fi

# Process all tracked files
git ls-files | while read -r file; do
  # Skip if file doesn't exist (might have been deleted)
  [ -f "$file" ] || continue
  
  # Skip if file has uncommitted changes
  if echo "$CHANGED_FILES" | grep -q "^$file$"; then
    echo "Skipping (has local changes): $file"
    continue
  fi
  
  # Get the last commit date for this file in Unix timestamp format
  # %at = author date, unix timestamp
  timestamp=$(git log -1 --format="%at" -- "$file")
  
  if [ -n "$timestamp" ]; then
    # Update the file's modification time using touch
    touch -m -t "$(date -d "@$timestamp" "+%Y%m%d%H%M.%S")" "$file"
    echo "Updated: $file → $(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")"
  else
    echo "Warning: Couldn't get timestamp for $file"
  fi
done

echo "✅ File modification times updated to match their last commit date (skipped files with local changes)."
exit 0