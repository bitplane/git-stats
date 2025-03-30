#!/bin/bash
# stats.sh - Extract commit stats from a Git repo
# Usage: ./stats.sh <repo-url>

set -eo pipefail

# Load helper functions
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/repo.sh"
source "${SCRIPT_DIR}/_utils.sh"
source "${SCRIPT_DIR}/process.sh"

# Process arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <repo-url>"
  exit 1
fi

repo_url="$1"
repo_name=$(basename "${repo_url%.git}")
cache_dir=".cache"
data_dir="data"
csv_file="$data_dir/${repo_name}.csv"
temp_stats="/tmp/${repo_name}_stats.tmp"

# Ensure directories exist
ensure_dir "$cache_dir"
ensure_dir "$data_dir"

# Get last processed date
last_date=$(get_last_date "$csv_file")
echo "Processing commits since $last_date for $repo_name"

# Clone or update repo
repo_dir=$(clone_or_update_repo "$repo_url" "$cache_dir")

# Extract commit log and process into daily stats
extract_log "$repo_dir" "$last_date" | process_log_data > "$temp_stats"

# Update CSV with new stats
update_csv "$csv_file" "$temp_stats"

# Clean up
rm -f "$temp_stats"

echo "Stats updated for $repo_name"
