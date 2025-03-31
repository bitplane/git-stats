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
temp_stats="/tmp/${repo_name}_stats.tmp"

ensure_dir "$cache_dir"
ensure_dir "$data_dir"

# Find last date from existing CSV, default "0001-01-01" if none
last_date="$(get_last_date "$csv_file")"
echo "Processing commits since $last_date for $repo_name"

# Clone or update
repo_dir="$(clone_or_update_repo "$repo_url" "$cache_dir")"

# Extract raw git log (since last_date), process with Python script
extract_log "$repo_dir" "$last_date" | python3 "${SCRIPT_DIR}/process.py" "$csv_file"

echo "Stats updated for $repo_name"
