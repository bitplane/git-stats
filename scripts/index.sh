#!/bin/bash
# scripts/index.sh
# Generates data/index.md listing each repo's stats

set -euo pipefail

DATA_DIR="data"

if [ ! -d "$DATA_DIR" ]; then
  echo "Error: data/ directory not found."
  exit 1
fi

CSV_FILES=$(find "$DATA_DIR" -maxdepth 1 -name "*.csv" | sort)
if [ -z "$CSV_FILES" ]; then
  echo "Error: No CSVs found in data/"
  exit 1
fi

cat <<EOF
# Repository Statistics

This page provides links to statistics for various open source repos.

## Repositories

| Repository | Commits | Lines Added | Lines Deleted | Active Period |
|------------|---------|-------------|---------------|--------------|
EOF

for csv in $CSV_FILES; do
  repo_name=$(basename "$csv" .csv)
  # Check if there's a header
  if head -1 "$csv" | grep -q '^date,commits'; then
    total_commits=$(awk -F, 'NR>1 {sum+=$2} END{print sum}' "$csv")
    total_added=$(awk -F, 'NR>1 {sum+=$4} END{print sum}' "$csv")
    total_deleted=$(awk -F, 'NR>1 {sum+=$5} END{print sum}' "$csv")
    first_date=$(awk -F, 'NR>1{print $1}' "$csv" | sort | head -1)
    last_date=$(awk -F, 'NR>1{print $1}' "$csv" | sort | tail -1)
  else
    # no header
    total_commits=$(awk -F, '{sum+=$2} END{print sum}' "$csv")
    total_added=$(awk -F, '{sum+=$4} END{print sum}' "$csv")
    total_deleted=$(awk -F, '{sum+=$5} END{print sum}' "$csv")
    first_date=$(awk -F, '{print $1}' "$csv" | sort | head -1)
    last_date=$(awk -F, '{print $1}' "$csv" | sort | tail -1)
  fi

  echo "| [${repo_name}](./${repo_name}/index.md) | ${total_commits} | ${total_added} | ${total_deleted} | ${first_date} to ${last_date} |"
done

cat <<EOF

## Recent Updates

Last updated: $(date +"%Y-%m-%d")
EOF
