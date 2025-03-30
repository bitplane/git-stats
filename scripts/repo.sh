#!/bin/bash
# repo.sh
# Provides functions used by stats.sh

set -eo pipefail

clone_or_update_repo() {
  if [ -d "$repo_path/.git" ]; then
    echo "Updating existing clone in $repo_path" >&2
    git -C "$repo_path" fetch --all --tags --prune
    git -C "$repo_path" pull --rebase
  else
    echo "Cloning $repo_url into $repo_path" >&2
    git clone "$repo_url" "$repo_path"
  fi

  echo "$repo_path"
}


# Extract git log in expected format: one COMMIT line per commit, then numstat
extract_log() {
  local repo_dir="$1"
  local since_date="${2:-2025-01-01}"

  echo "Extracting log since $since_date from $repo_dir" >&2
  cd "$repo_dir" || return 1

  git log --since="$since_date" \
          --date=short \
          --pretty=format:'COMMIT %H %ad' \
          --numstat
}
