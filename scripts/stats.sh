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

ensure_dir "$cache_dir"
ensure_dir "$data_dir"

# Clone or update repository
repo_dir="$(clone_or_update_repo "$repo_url" "$cache_dir")"

# Get the last processed commit hash if available
if [ -f "$latest_file" ] && [ -s "$latest_file" ]; then
  last_hash=$(cat "$latest_file")
  echo "Processing commits since hash $last_hash for $repo_name"
  extract_log "$repo_dir" "$last_hash" | tee "$repo_dir".log | python3 "${SCRIPT_DIR}/process.py" "$csv_file"
else
  # First run - no filter
  echo "No previous hash found. Processing all commits for $repo_name"
  extract_log "$repo_dir" "" | tee "$repo_dir".log | python3 "${SCRIPT_DIR}/process.py" "$csv_file"
fi

echo "Stats updated for $repo_name"
