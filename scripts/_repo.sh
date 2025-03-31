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

  mkdir -p "$cache_dir" >&2

  if [ -d "$repo_path" ]; then
    cd "$repo_path" >&2 || { echo "Failed to change to repository directory" >&2; exit 1; }
    git fetch --all --tags >&2
  else
    if [ -f "$latest_file" ]; then
      local file_date=$(date -r "$latest_file" +%Y-%m-%d 2>/dev/null)
      if [ -n "$file_date" ]; then
        local shallow_date=$(date -d "$file_date - 3 days" +%Y-%m-%d 2>/dev/null || echo "$file_date")
        git clone --bare --shallow-since="$shallow_date" "$repo_url" "$repo_path" >&2
      else
        git clone --bare "$repo_url" "$repo_path" >&2
      fi
    else
      git clone --bare "$repo_url" "$repo_path" >&2
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
    git log "$since_hash..HEAD" --date=short --pretty="tformat:COMMIT %H %ad %aE" --numstat --reverse
  else
    git log --all --date=short --pretty="tformat:COMMIT %H %ad %aE" --numstat --reverse
  fi
}