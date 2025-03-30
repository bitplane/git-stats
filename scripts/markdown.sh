#!/bin/bash
# generate_md.sh
# Generates a markdown report from a CSV file
# Usage: ./generate_md.sh input.csv > output.md

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <input.csv>"
  exit 1
fi

INPUT_CSV="$1"
REPO_NAME=$(basename "$INPUT_CSV" .csv)

# Read CSV header to get column names (skip if no header exists)
if [ -f "$INPUT_CSV" ] && [ -s "$INPUT_CSV" ]; then
  HEADER=$(head -n 1 "$INPUT_CSV")
  if [[ "$HEADER" == *"date"* ]]; then
    # Has a header, skip first line when processing
    HAS_HEADER=true
  else
    # No header, assume standard format
    HAS_HEADER=false
  fi
else
  echo "Error: CSV file is empty or doesn't exist."
  exit 1
fi

# Get basic stats
if [ "$HAS_HEADER" = true ]; then
  TOTAL_COMMITS=$(awk -F, 'NR>1 {sum+=$2} END {print sum}' "$INPUT_CSV")
  TOTAL_LINES_ADDED=$(awk -F, 'NR>1 {sum+=$4} END {print sum}' "$INPUT_CSV")
  TOTAL_LINES_DELETED=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' "$INPUT_CSV")
  TOTAL_FILES_CHANGED=$(awk -F, 'NR>1 {sum+=$6} END {print sum}' "$INPUT_CSV")
  
  # Get date range
  FIRST_DATE=$(awk -F, 'NR>1 {print $1}' "$INPUT_CSV" | sort | head -n 1)
  LAST_DATE=$(awk -F, 'NR>1 {print $1}' "$INPUT_CSV" | sort | tail -n 1)
  
  # Get top organizations
  if [ "$(head -n 1 "$INPUT_CSV")" == *"orgs"* ]; then
    # Extract all org mentions, count them and sort
    TOP_ORGS=$(awk -F, 'NR>1 && $3!="" {split($3,orgs,"|"); for (org in orgs) {print orgs[org]}}' "$INPUT_CSV" | 
               sort | uniq -c | sort -nr | head -5 | 
               awk '{print "- " $2 " (" $1 " commits)"}')
  else
    TOP_ORGS="- Organization data not available"
  fi
else
  # No header, assume standard columns
  TOTAL_COMMITS=$(awk -F, '{sum+=$2} END {print sum}' "$INPUT_CSV")
  TOTAL_LINES_ADDED=$(awk -F, '{sum+=$4} END {print sum}' "$INPUT_CSV")
  TOTAL_LINES_DELETED=$(awk -F, '{sum+=$5} END {print sum}' "$INPUT_CSV")
  TOTAL_FILES_CHANGED=$(awk -F, '{sum+=$6} END {print sum}' "$INPUT_CSV")
  
  FIRST_DATE=$(awk -F, '{print $1}' "$INPUT_CSV" | sort | head -n 1)
  LAST_DATE=$(awk -F, '{print $1}' "$INPUT_CSV" | sort | tail -n 1)
  
  TOP_ORGS="- Organization data not available"
fi

# Generate the markdown content
cat << EOF
# ${REPO_NAME} Repository Statistics

## Overview

This report provides statistics for the ${REPO_NAME} repository from ${FIRST_DATE} to ${LAST_DATE}.

## Summary

- **Total Commits:** ${TOTAL_COMMITS}
- **Total Lines Added:** ${TOTAL_LINES_ADDED}
- **Total Lines Deleted:** ${TOTAL_LINES_DELETED}
- **Total Files Changed:** ${TOTAL_FILES_CHANGED}
- **Active Period:** ${FIRST_DATE} to ${LAST_DATE}

## Top Contributing Organizations

${TOP_ORGS}

## Visualizations

### Commit Activity

![Commits over time](./commits.svg)

### Code Changes

![Lines of code changes](./lines.svg)

## Recent Activity

The table below shows the most recent activity in the repository:

| Date | Commits | Lines Added | Lines Deleted | Files Changed |
|------|---------|-------------|---------------|---------------|
EOF

# Add the most recent entries to the table (last 10 days with activity)
if [ "$HAS_HEADER" = true ]; then
  tail -n+2 "$INPUT_CSV" | sort -t, -k1,1r | head -10 | 
  awk -F, '{print "| " $1 " | " $2 " | " $4 " | " $5 " | " $6 " |"}' >> /dev/stdout
else
  sort -t, -k1,1r "$INPUT_CSV" | head -10 | 
  awk -F, '{print "| " $1 " | " $2 " | " $4 " | " $5 " | " $6 " |"}' >> /dev/stdout
fi

cat << EOF

*This report was automatically generated on $(date +"%Y-%m-%d")*
EOF