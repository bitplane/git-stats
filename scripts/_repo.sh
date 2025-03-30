# scripts/repo.sh
# Provides two functions used by stats.sh:
#   1) clone_or_update_repo <repo-url> <cache-dir>
#   2) extract_log          <repo-dir>  <since-date>
#
# This version includes the author email and handles multiple commits properly.

clone_or_update_repo() {
  local repo_url="$1"
  local cache_dir="$2"

  # Derive a local path: .cache/<repo_name>
  local repo_name
  repo_name="$(basename "${repo_url%.git}")"
  local repo_path="${cache_dir}/${repo_name}"

  echo "$repo_path"

  if [ -d "$repo_path" ]; then
    echo "Updating existing clone in $repo_path"   >&2
    git -C "$repo_path" fetch --all --tags --prune >&2 || exit 1
    git -C "$repo_path" pull --rebase              >&2 || exit 1
  else
    echo "Cloning $repo_url into $repo_path"       >&2
    git clone "$repo_url" "$repo_path"             >&2 || exit 1
  fi

}

extract_log() {
  local repo_dir="$1"
  local since_date="${2:-0001-01-01}"

  echo "Extracting log since $since_date from $repo_dir" >&2
  cd "$repo_dir" || return 1

  # Use --reverse to ensure chronological order
  # The "COMMIT" line captures: <hash> <YYYY-MM-DD> <author-email>
  git log --since="$since_date" \
          --date=short \
          --no-merges \
          --reverse \
          --pretty=format:'COMMIT %H %ad %aE' \
          --numstat
}
