#!/bin/bash
# scripts/weekly-update.sh
# If any CSV is newer than a week, touches repos.txt to refresh Make dependencies.

set -euo pipefail

DATA_DIR="data"
REPOS_FILE="repos.txt"

if [ ! -d "$DATA_DIR" ]; then
  echo "No data/ directory yet. Probably no CSVs exist."
  exit 0
fi

CURRENT_TIME=$(date +%s)
ONE_WEEK=$((7 * 24 * 60 * 60))

NEWEST_CSV=$(find "$DATA_DIR" -name "*.csv" -type f -exec stat -c "%Y %n" {} \; | sort -nr | head -n1)

if [ -z "$NEWEST_CSV" ]; then
  echo "No CSV found in data/"
  exit 0
fi

NEWEST_TIME=$(echo "$NEWEST_CSV" | cut -d' ' -f1)
NEWEST_FILE=$(echo "$NEWEST_CSV" | cut -d' ' -f2-)
TIME_DIFF=$((CURRENT_TIME - NEWEST_TIME))

if [ "$TIME_DIFF" -lt "$ONE_WEEK" ]; then
  echo "Newest CSV is under a week old: $NEWEST_FILE"
  echo "Updating repos.txt timestamp..."
  touch "$REPOS_FILE"
else
  echo "All CSVs are older than a week."
  echo "Newest CSV is: $NEWEST_FILE"
fi
