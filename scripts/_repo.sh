#!/bin/bash
# scripts/_repo.sh
# Provides two functions used by stats.sh:
#   1) clone_or_update_repo <repo-url> <cache-dir>
#   2) extract_log          <repo-dir>  <hash>

clone_or_update_repo() {
  local repo_url="$1"
  local cache_dir="$2"
  local repo_name=$(basename "${repo_url%.git}")
  local repo_path="${cache_dir}/${repo_name}"
  local latest_file="data/${repo_name}.latest"
  local csv_file="data/${repo_name}.csv"

  mkdir -p "$cache_dir" >&2

  if [ -d "$repo_path" ]; then
    cd "$repo_path" >&2 || { echo "Failed to change to repository directory" >&2; exit 1; }
    git fetch --tags >&2
  else
    # Get the last date from CSV using the Python script
    if [ -f "$csv_file" ]; then
      local shallow_date=$(python3 scripts/get_last_date.py "$csv_file" "$(date -d "-30 days" +%Y-%m-%d)")
      echo "Using shallow-since=$shallow_date from CSV history" >&2
      git clone --bare --shallow-since="$shallow_date" "$repo_url" "$repo_path" >&2
    else
      local shallow_date=1970-01-01
      echo "No CSV history found, using shallow-since=$shallow_date" >&2
      git clone --bare --shallow-since="$shallow_date" "$repo_url" "$repo_path" >&2
    fi
    cd "$repo_path" >&2 || { echo "Failed to change to repository directory" >&2; exit 1; }
  fi

  echo "$repo_path"
}

extract_log() {
  local repo_dir="$1"
  local since_hash="$2"

  cd "$repo_dir" >&2 || { echo "Failed to change to repository directory" >&2; exit 1; }

  if [ -n "$since_hash" ]; then
    # Try to use the specified hash range
    if git cat-file -e "$since_hash" 2>/dev/null; then
      git log "$since_hash..HEAD" --date=short --pretty="tformat:COMMIT %H %ad %aE" --numstat --reverse
    else
      echo "Warning: Commit $since_hash not found in shallow clone" >&2
      echo "Falling back to all available history" >&2
      git log --date=short --pretty="tformat:COMMIT %H %ad %aE" --numstat --reverse
    fi
  else
    git log --all --date=short --pretty="tformat:COMMIT %H %ad %aE" --numstat --reverse
  fi
}
