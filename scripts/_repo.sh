#!/bin/bash
# scripts/repo.sh
# Provides two functions used by stats.sh:
#   1) clone_or_update_repo <repo-url> <cache-dir>
#   2) extract_log          <repo-dir>  <since-date>

clone_or_update_repo() {
  local repo_url="$1"
  local cache_dir="$2"

  # Derive a local path: .cache/<repo_name>
  local repo_name
  repo_name="$(basename "${repo_url%.git}")"
  local repo_path="${cache_dir}/${repo_name}"

  # Ensure cache directory exists
  mkdir -p "$cache_dir" 2>&2

  if [ -d "$repo_path" ]; then
    echo "Updating existing repository in $repo_path"   >&2
    # Change to the repository directory before running git commands
    cd "$repo_path" 2>&2 || { echo "Failed to change to repository directory" >&2; exit 1; }
    
    # Fetch all branches and history for a bare repository
    git fetch --all --tags 2>&2
  else
    echo "Cloning $repo_url into $repo_path as a bare repository" >&2
    # Clone as a bare repository to get full history
    git clone --bare "$repo_url" "$repo_path" 2>&2
    
    # Change to the newly cloned repository
    cd "$repo_path" 2>&2 || { echo "Failed to change to repository directory" >&2; exit 1; }
  fi

  # Verify we have commits
  local commit_count
  commit_count=$(git rev-list --count --all 2>&2)
  echo "Total commits in repository: $commit_count" >&2

  # Echo just the path to stdout, for stats.sh to capture
  echo "$repo_path"
}

extract_log() {
  local repo_dir="$1"
  local since_date="${2:-0001-01-01}"

  echo "Extracting log since $since_date from $repo_dir" >&2
  cd "$repo_dir" 2>&2 || { echo "Failed to change to repository directory" >&2; exit 1; }

  # Use absolute path for log file
  local log_file
  log_file="$(pwd).log"

  # Comprehensive log command for bare repository
  # Tee the output to a log file for inspection
  git log --all \
    --since="$since_date" \
    --date=short \
    --pretty='tformat:COMMIT %H %ad %aE' \
    --numstat \
    --reverse 2>&2 | \
  tee "$log_file"
}
