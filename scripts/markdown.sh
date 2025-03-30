#!/bin/bash
# scripts/markdown.sh
# Generates a per-repo markdown from a .csv

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <input.csv>"
  exit 1
fi

INPUT_CSV="$1"
REPO_NAME="$(basename "$INPUT_CSV" .csv)"

if [ ! -s "$INPUT_CSV" ]; then
  echo "Error: CSV empty or missing: $INPUT_CSV" >&2
  exit 1
fi

# Check if there's a header line
HEADER_LINE="$(head -1 "$INPUT_CSV")"
HAS_HEADER=false
if echo "$HEADER_LINE" | grep -q '^date,commits,'; then
  HAS_HEADER=true
fi

# Basic sums
if $HAS_HEADER; then
  TOTAL_COMMITS=$(awk -F, 'NR>1 {sum+=$2} END{print sum}' "$INPUT_CSV")
  TOTAL_ADDED=$(awk -F, 'NR>1 {sum+=$4} END{print sum}' "$INPUT_CSV")
  TOTAL_DELETED=$(awk -F, 'NR>1 {sum+=$5} END{print sum}' "$INPUT_CSV")
  TOTAL_FILES_CHANGED=$(awk -F, 'NR>1 {sum+=$6} END{print sum}' "$INPUT_CSV")
  TOTAL_CONTRIB=$(awk -F, 'NR>1 {sum+=$7} END{print sum}' "$INPUT_CSV")
  FIRST_DATE=$(awk -F, 'NR>1 {print $1}' "$INPUT_CSV" | sort | head -1)
  LAST_DATE=$(awk -F, 'NR>1 {print $1}' "$INPUT_CSV" | sort | tail -1)
else
  TOTAL_COMMITS=$(awk -F, '{sum+=$2} END{print sum}' "$INPUT_CSV")
  TOTAL_ADDED=$(awk -F, '{sum+=$4} END{print sum}' "$INPUT_CSV")
  TOTAL_DELETED=$(awk -F, '{sum+=$5} END{print sum}' "$INPUT_CSV")
  TOTAL_FILES_CHANGED=$(awk -F, '{sum+=$6} END{print sum}' "$INPUT_CSV")
  TOTAL_CONTRIB=$(awk -F, '{sum+=$7} END{print sum}' "$INPUT_CSV")
  FIRST_DATE=$(awk -F, '{print $1}' "$INPUT_CSV" | sort | head -1)
  LAST_DATE=$(awk -F, '{print $1}' "$INPUT_CSV" | sort | tail -1)
fi

cat <<EOF
# ${REPO_NAME} Repository Statistics

## Overview

This report covers **${REPO_NAME}** from ${FIRST_DATE} to ${LAST_DATE}.

## Summary

- **Total Commits:** ${TOTAL_COMMITS}
- **Total Lines Added:** ${TOTAL_ADDED}
- **Total Lines Deleted:** ${TOTAL_DELETED}
- **Total Files Changed:** ${TOTAL_FILES_CHANGED}
- **(Sum of) Daily Contributors:** ${TOTAL_CONTRIB}  
  *(this is a naive sum, not unique across the entire timespan)*

## Visualizations

**Commits Over Time**

![Commits](./commits.svg)

**Code Changes**

![Lines of code changes](./lines.svg)

## Recent Activity (last 10 entries)

| Date | Commits | Lines Added | Lines Deleted | Files Changed | Contributors |
|------|---------|-------------|---------------|---------------|--------------|
EOF

if $HAS_HEADER; then
  tail -n +2 "$INPUT_CSV" | sort -t, -k1,1r | head -10 | \
    awk -F, '{print "| "$1" | "$2" | "$4" | "$5" | "$6" | "$7" |"}'
else
  sort -t, -k1,1r "$INPUT_CSV" | head -10 | \
    awk -F, '{print "| "$1" | "$2" | "$4" | "$5" | "$6" | "$7" |"}'
fi

echo ""
echo "*Generated on $(date +%Y-%m-%d)*"
