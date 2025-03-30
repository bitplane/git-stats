#!/bin/bash
set -euo pipefail

# Check if repos.txt exists
if [ ! -f repos.txt ]; then
  echo "Error: repos.txt not found!"
  exit 1
fi

# Loop through each line in repos.txt
while IFS= read -r repo || [ -n "$repo" ]; do
  # Skip empty lines or lines starting with a hash (comments)
  if [ -z "$repo" ] || [[ "$repo" =~ ^# ]]; then
    continue
  fi
  echo "Processing repository: $repo"
  ./stats.sh "$repo"
done < repos.txt

echo "✅ All repositories processed."
