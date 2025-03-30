#!/bin/bash
# stats.sh - Collect git commit stats from a repo and append them to a CSV file.
# Usage: ./stats.sh <git-remote-url>
#
# Requirements:
#   - The repo is stored in ./.cache/<repo-name>
#   - The output CSV will be written to ./data/<repo-name>.csv
#   - A log file of git log output is kept in the cache directory (not in /tmp)
#   - If the CSV's last date is empty, we default to 0001-01-01T00:00:00.
#   - New commits (since the last date) are processed and appended without duplicate days.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <git-repo-url>"
  exit 1
fi

REPO_URL="$1"
# Extract repo name from URL (remove trailing .git if present)
REPO_NAME=$(basename "$REPO_URL")
REPO_NAME=${REPO_NAME%.git}

# Directories and file paths
CACHE_DIR="$(pwd)/.cache"
REPO_DIR="$CACHE_DIR/$REPO_NAME"
DATA_DIR="$(pwd)/data"
CSV_FILE="$DATA_DIR/${REPO_NAME}.csv"
# Log file stored in the cache directory
LOG_FILE="$CACHE_DIR/${REPO_NAME}_gitstats.log"
TMP_DIR="$CACHE_DIR/${REPO_NAME}_tmp"

# Ensure all directories exist
mkdir -p "$CACHE_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$TMP_DIR"

# Get current date for filtering future dates
TODAY=$(date -u +"%Y-%m-%d")

# Default date for fresh runs
LAST_DATE="0001-01-01T00:00:00"

# If CSV exists and has content, get the last date (first column)
if [ -f "$CSV_FILE" ] && [ -s "$CSV_FILE" ]; then
  # Find the last non-empty line with a valid date format (YYYY-MM-DD)
  LAST_DATE_CANDIDATE=$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' "$CSV_FILE" | tail -n 1 | cut -d, -f1)
  
  # Filter out future dates
  if [ -n "$LAST_DATE_CANDIDATE" ]; then
    if [ "$LAST_DATE_CANDIDATE" \> "$TODAY" ]; then
      echo "Warning: Found future date in CSV: $LAST_DATE_CANDIDATE, using today instead."
      LAST_DATE_CANDIDATE="$TODAY"
    fi
    LAST_DATE="$LAST_DATE_CANDIDATE"
  fi
fi

# Clone the repo if it doesn't exist, otherwise update it
if [ -d "$REPO_DIR" ]; then
  echo "Using cached repo: $REPO_DIR"
  pushd "$REPO_DIR" > /dev/null
  # Just fetch, no need for pull as we only need the commit metadata
  git fetch --all
  popd > /dev/null
else
  echo "Cloning repo: $REPO_URL into $REPO_DIR"
  # Use shallow clone with earliest date
  git clone --bare --shallow-since="$LAST_DATE" "$REPO_URL" "$REPO_DIR"
fi

echo "Processing commits since $LAST_DATE..."
pushd "$REPO_DIR" > /dev/null

# Get the number of CPU cores for parallelization
NUM_CORES=$(nproc || echo 4)  # Default to 4 if nproc fails
echo "Using $NUM_CORES CPU cores for processing"

# For very large repos, split by year ranges to process in parallel
# Get range of years from git log
YEARS_RANGE=$(git log --since="$LAST_DATE" --format="%ad" --date=format:"%Y" | sort -u)

# Use a more efficient method for git log - get all the stats we need in one go
# Write output directly in the CSV format we need
# --numstat gives lines added/removed per file
git log --since="$LAST_DATE" --format='COMMIT_START%n%ad' --date=iso --numstat > "$LOG_FILE"

# Check if log file is empty (no new commits)
if [ ! -s "$LOG_FILE" ]; then
  echo "No new commits since $LAST_DATE. Nothing to process."
  popd > /dev/null
  exit 0
fi

popd > /dev/null

echo "Aggregating commit stats by day..."

# Process the log file in parallel using GNU parallel if available
if command -v parallel > /dev/null 2>&1; then
  # Split log file into chunks for parallel processing
  LINES_PER_CHUNK=$(( $(wc -l < "$LOG_FILE") / NUM_CORES + 1 ))
  split -l "$LINES_PER_CHUNK" "$LOG_FILE" "$TMP_DIR/chunk_"
  
  process_chunk() {
    local chunk_file="$1"
    local chunk_output="$chunk_file.out"
    
    # Process each chunk to get daily stats
    awk '
    BEGIN { 
      commit_date = ""; 
      files = 0; 
      added = 0; 
      deleted = 0;
    }
    
    /^COMMIT_START/ { in_commit=1; next }
    
    in_commit && /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      # Extract just the date part
      commit_date = substr($0, 1, 10);
      in_commit = 0;
      next;
    }
    
    /^[0-9]+\t[0-9]+\t/ {
      # Count stats from numstat output: lines-added, lines-deleted, filename
      added += $1;
      deleted += $2;
      files++;
      next;
    }
    
    /^$/ {
      # Blank line marks end of a commit
      if (commit_date != "") {
        # Ensure we are not processing future dates
        if (commit_date <= "'"$TODAY"'") {
          # Output stats for this commit: date,1,author,added,deleted,files
          print commit_date ",1,," added "," deleted "," files;
        }
        # Reset counters for next commit
        commit_date = "";
        files = 0;
        added = 0;
        deleted = 0;
      }
    }
    ' "$chunk_file" > "$chunk_output"
  }
  
  export -f process_chunk
  find "$TMP_DIR" -name "chunk_*" -not -name "*.out" | parallel -j "$NUM_CORES" process_chunk {}
  
  # Combine chunk results and aggregate by day
  cat "$TMP_DIR"/chunk_*.out | sort | awk '
  BEGIN { FS=OFS="," }
  {
    date=$1;
    commits=$2;
    added=$4;
    deleted=$5;
    files=$6;
    
    dates[date] += commits;
    adds[date] += added;
    dels[date] += deleted;
    fs[date] += files;
  }
  END {
    for (date in dates) {
      print date, dates[date], "", adds[date], dels[date], fs[date];
    }
  }
  ' | sort > "$TMP_DIR/daily_stats.csv"
else
  # Fallback to single-threaded processing if parallel is not available
  echo "GNU parallel not found. Using single-threaded processing (slower)."
  awk '
  BEGIN { 
    FS=OFS=",";
    commit_date = ""; 
    files = 0; 
    added = 0; 
    deleted = 0;
  }
  
  /^COMMIT_START/ { in_commit=1; next }
  
  in_commit && /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
    # Extract just the date part
    commit_date = substr($0, 1, 10);
    in_commit = 0;
    next;
  }
  
  /^[0-9]+\t[0-9]+\t/ {
    # Count stats from numstat output: lines-added, lines-deleted, filename
    added += $1;
    deleted += $2;
    files++;
    next;
  }
  
  /^$/ {
    # Blank line marks end of a commit
    if (commit_date != "") {
      # Ensure we are not processing future dates
      if (commit_date <= "'"$TODAY"'") {
        # Save stats for this commit
        dates[commit_date] += 1;
        adds[commit_date] += added;
        dels[commit_date] += deleted;
        fs[commit_date] += files;
      }
      # Reset counters for next commit
      commit_date = "";
      files = 0;
      added = 0;
      deleted = 0;
    }
  }
  
  END {
    # Output aggregated daily stats
    for (date in dates) {
      print date, dates[date], "", adds[date], dels[date], fs[date];
    }
  }
  ' "$LOG_FILE" | sort > "$TMP_DIR/daily_stats.csv"
fi

# Process the aggregated daily stats
NEW_STATS=$(cat "$TMP_DIR/daily_stats.csv")

# Only proceed if we have stats to add
if [ -n "$NEW_STATS" ]; then
  # If the CSV file exists, we need to remove lines with the same dates as the new stats
  if [ -f "$CSV_FILE" ]; then
    # Get all dates from new stats
    cut -d, -f1 "$TMP_DIR/daily_stats.csv" > "$TMP_DIR/new_dates.txt"
    
    # Filter out existing lines with the same dates and future dates
    {
      grep -vf "$TMP_DIR/new_dates.txt" "$CSV_FILE" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | while IFS= read -r line; do
        line_date=$(echo "$line" | cut -d, -f1)
        if [ "$line_date" \<= "$TODAY" ]; then
          echo "$line"
        else
          echo "Removing future date from CSV: $line_date" >&2
        fi
      done 
    } > "${CSV_FILE}.tmp"
    
    mv "${CSV_FILE}.tmp" "$CSV_FILE"
  fi
  
  # Append new stats
  cat "$TMP_DIR/daily_stats.csv" >> "$CSV_FILE"
  echo "✅ Done. Stats written to $CSV_FILE"
else
  echo "No new valid stats to append."
fi

# Clean up temporary files
rm -rf "$TMP_DIR"