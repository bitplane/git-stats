#!/bin/bash
set -euo pipefail

# USAGE: ./stats.sh <git-repo-URL-or-local-path>

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <git-repo-URL-or-local-path>"
  exit 1
fi

INPUT="$1"
CACHE_DIR=".cache"
DATA_DIR="data"
mkdir -p "$CACHE_DIR" "$DATA_DIR"

# Determine if the input is a remote URL or a local path.
if [[ "$INPUT" =~ ^https?:// ]]; then
  REPO_NAME=$(basename "$INPUT" .git)
else
  REPO_NAME=$(basename "$INPUT")
  REPO_NAME="${REPO_NAME%.git}"
fi

REPO_PATH="$CACHE_DIR/$REPO_NAME"

if [ -d "$REPO_PATH/.git" ]; then
  echo "Using cached repository at $REPO_PATH"
  # Update the repo to get the latest changes.
  pushd "$REPO_PATH" > /dev/null
  git fetch --all --quiet
  popd > /dev/null
else
  if [[ "$INPUT" =~ ^https?:// ]]; then
    echo "Cloning remote repo $INPUT into $REPO_PATH..."
    git clone --quiet "$INPUT" "$REPO_PATH"
  else
    echo "Copying local repo from $INPUT into $REPO_PATH..."
    cp -r "$INPUT" "$REPO_PATH"
  fi
fi

CSV_FILE="$DATA_DIR/${REPO_NAME}.csv"

# Determine the starting date: if the CSV exists, use its last day; otherwise use the epoch.
if [ -f "$CSV_FILE" ]; then
  LAST_DATE=$(tail -n1 "$CSV_FILE" | cut -d',' -f1)
else
  LAST_DATE="0001-01-01"
fi

echo "Processing commits since $LAST_DATE ..."

# Run git log inside the cached repo without changing your working directory.
pushd "$REPO_PATH" > /dev/null

# Save log to a temporary file. We use --date=short so dates are in YYYY-MM-DD format.
TMP_LOG=$(mktemp)
git log --since="$LAST_DATE" --numstat --pretty=format:"commit %H %ad" --date=short > "$TMP_LOG"

popd > /dev/null

# Process the log with awk to aggregate daily stats.
# It sums up:
#   - commits per day
#   - total lines added
#   - total lines deleted
#   - total files changed (i.e. each numstat block counts as one file change)
awk '
BEGIN { OFS="," }
$1 == "commit" {
  # When encountering a new commit, add the previous commit’s stats to the daily totals.
  if (commit_date != "") {
    daily_commits[commit_date]++
    daily_added[commit_date] += commit_added
    daily_deleted[commit_date] += commit_deleted
    daily_files[commit_date] += commit_files
  }
  commit_date = $3
  commit_added = 0
  commit_deleted = 0
  commit_files = 0
  next
}
NF == 3 && $1 ~ /^[0-9]+$/ {
  commit_added += $1
  commit_deleted += $2
  commit_files++
}
END {
  if (commit_date != "") {
    daily_commits[commit_date]++
    daily_added[commit_date] += commit_added
    daily_deleted[commit_date] += commit_deleted
    daily_files[commit_date] += commit_files
  }
  for (d in daily_commits)
    print d, daily_commits[d], "", daily_added[d], daily_deleted[d], daily_files[d]
}
' "$TMP_LOG" | sort > "$DATA_DIR/${REPO_NAME}_new.csv"

# Append new (non-duplicate) days to the CSV file.
if [ -f "$CSV_FILE" ]; then
  # Exclude days already in the CSV.
  cut -d',' -f1 "$CSV_FILE" > .existing_dates.tmp
  grep -F -x -v -f .existing_dates.tmp "$DATA_DIR/${REPO_NAME}_new.csv" >> "$CSV_FILE"
  rm .existing_dates.tmp
else
  cp "$DATA_DIR/${REPO_NAME}_new.csv" "$CSV_FILE"
fi

rm "$TMP_LOG" "$DATA_DIR/${REPO_NAME}_new.csv"

echo "✅ Done. Stats written to $CSV_FILE"
