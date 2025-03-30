#!/bin/bash
# index.sh
# Generates main index.md with links to all repository stats
# Usage: ./index.sh > data/index.md

set -euo pipefail

DATA_DIR="data"

# Check if data directory exists
if [ ! -d "$DATA_DIR" ]; then
  echo "Error: Data directory not found."
  exit 1
fi

# Find all CSV files
CSV_FILES=$(find "$DATA_DIR" -maxdepth 1 -name "*.csv" | sort)

if [ -z "$CSV_FILES" ]; then
  echo "Error: No CSV files found in $DATA_DIR."
  exit 1
fi

# Generate the index markdown content
cat << EOF
# Repository Statistics

This page provides links to statistics for various open source repositories.

## Repositories

| Repository | Commits | Lines Added | Lines Deleted | Active Period |
|------------|---------|-------------|---------------|--------------|
EOF

# Process each CSV file
for csv_file in $CSV_FILES; do
  repo_name=$(basename "$csv_file" .csv)
  
  # Skip first line if it's a header
  if head -n 1 "$csv_file" | grep -q "date,commits"; then
    has_header=true
  else
    has_header=false
  fi
  
  # Extract stats
  if [ "$has_header" = true ]; then
    total_commits=$(awk -F, 'NR>1 {sum+=$2} END {print sum}' "$csv_file")
    total_lines_added=$(awk -F, 'NR>1 {sum+=$4} END {print sum}' "$csv_file")
    total_lines_deleted=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' "$csv_file")
    first_date=$(awk -F, 'NR>1 {print $1}' "$csv_file" | sort | head -n 1)
    last_date=$(awk -F, 'NR>1 {print $1}' "$csv_file" | sort | tail -n 1)
  else
    total_commits=$(awk -F, '{sum+=$2} END {print sum}' "$csv_file")
    total_lines_added=$(awk -F, '{sum+=$4} END {print sum}' "$csv_file")
    total_lines_deleted=$(awk -F, '{sum+=$5} END {print sum}' "$csv_file")
    first_date=$(awk -F, '{print $1}' "$csv_file" | sort | head -n 1)
    last_date=$(awk -F, '{print $1}' "$csv_file" | sort | tail -n 1)
  fi
  
  # Format the active period
  active_period="${first_date} to ${last_date}"
  
  # Write the table row with link to detailed stats
  echo "| [${repo_name}](./${repo_name}/index.md) | ${total_commits} | ${total_lines_added} | ${total_lines_deleted} | ${active_period} |"
done

cat << EOF

## Recent Updates

Last updated: $(date +"%Y-%m-%d")

## Visualization 

For each repository, you can view:
- Commit activity over time
- Lines of code added and removed
- Contributing organizations

Click on a repository name in the table above to see detailed statistics.
EOF