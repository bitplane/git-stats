#!/bin/bash
# update-repos-mtime.sh
# Updates the modification time of repos.txt if any CSV file is newer than a week
# Usage: ./update-repos-mtime.sh

set -euo pipefail

DATA_DIR="data"
REPOS_FILE="repos.txt"

# Check if data directory exists
if [ ! -d "$DATA_DIR" ]; then
  echo "Data directory not found. No CSVs to check."
  exit 0
fi

# Get current date in seconds since epoch
CURRENT_TIME=$(date +%s)

# One week in seconds
ONE_WEEK=$((7 * 24 * 60 * 60))

# Find the newest CSV file
NEWEST_CSV=$(find "$DATA_DIR" -name "*.csv" -type f -exec stat -c "%Y %n" {} \; | sort -nr | head -n1)

if [ -z "$NEWEST_CSV" ]; then
  echo "No CSV files found in $DATA_DIR."
  exit 0
fi

# Extract timestamp and filename
NEWEST_TIME=$(echo "$NEWEST_CSV" | cut -d' ' -f1)
NEWEST_FILE=$(echo "$NEWEST_CSV" | cut -d' ' -f2-)

# Calculate time difference
TIME_DIFF=$((CURRENT_TIME - NEWEST_TIME))

# Check if newest CSV is newer than a week
if [ "$TIME_DIFF" -lt "$ONE_WEEK" ]; then
  echo "Newest CSV ($NEWEST_FILE) is less than a week old."
  echo "Updating repos.txt modification time..."
  touch "$REPOS_FILE"
  echo "Done. repos.txt timestamp updated."
else
  echo "All CSVs are older than a week. No update needed."
  echo "Newest CSV: $NEWEST_FILE ($(date -d @"$NEWEST_TIME" "+%Y-%m-%d %H:%M:%S"))"
fi