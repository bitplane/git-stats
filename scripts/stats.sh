#!/bin/bash
# Usage: ./stats.sh <repo-url>
#  Clones/updates the repo in .cache/, extracts daily stats, merges into CSV

set -eo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/_repo.sh"
source "${SCRIPT_DIR}/_utils.sh"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <repo-url>"
  exit 1
fi

repo_url="$1"
repo_name="$(basename "${repo_url%.git}")"

cache_dir=".cache"
data_dir="data"
csv_file="$data_dir/${repo_name}.csv"
latest_file="$data_dir/${repo_name}.latest"
temp_stats="/tmp/${repo_name}_stats.tmp"

ensure_dir "$cache_dir"
ensure_dir "$data_dir"

# Get the last processed commit hash if available
since_arg=""
if [ -f "$latest_file" ]; then
  last_hash=$(cat "$latest_file")
  if [ -n "$last_hash" ]; then
    since_arg="$last_hash~1" # Start from parent of last processed commit
    echo "Processing commits since hash $last_hash for $repo_name"
  else
    echo "Empty hash file found. Processing all commits for $repo_name"
    since_arg="0001-01-01" # Practically the beginning of time
  fi
else
  # No hash file - for the first run, we process everything
  echo "No previous hash file found. Processing all commits for $repo_name"
  since_arg="0001-01-01" # Practically the beginning of time
fi

# Clone or update
repo_dir="$(clone_or_update_repo "$repo_url" "$cache_dir")"

# Extract raw git log and process with Python script
extract_log "$repo_dir" "$since_arg" | python3 "${SCRIPT_DIR}/process.py" "$csv_file"

echo "Stats updated for $repo_name"