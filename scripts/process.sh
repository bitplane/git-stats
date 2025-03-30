#!/bin/bash
# scripts/process.sh
# Aggregates the raw "git log --numstat" into daily CSV rows.

process_log_data() {
  awk -F'\t' '
    BEGIN {
      prev_date = ""
      commits   = 0
      files     = 0
      added     = 0
      deleted   = 0

      # We store domain->commit_count in an AWK array "org_commits"
      # and a set of unique authors in "authors" for contributor count
      split("", org_commits)
      split("", authors)
    }

    # Each new commit line: "COMMIT <hash> <YYYY-MM-DD> <author-email>"
    /^COMMIT / {
      # Extract fields by splitting the entire line (space-delimited)
      # "COMMIT", "hash", "date", "author@email"
      n = split($0, parts, " ")
      # parts[1]="COMMIT", parts[2]=<hash>, parts[3]=<date>, parts[4]=<author>
      commit_date = parts[3]
      author_email = parts[4]

      # If we have a previous date that differs from the new commit_date,
      # output the accumulated stats for that day, then reset.
      if (prev_date != "" && commit_date != prev_date) {
        # Build orgs column like "microsoft.com:12|mozilla.org:10"
        orgs_str = ""
        sep = ""
        for (d in org_commits) {
          orgs_str = orgs_str sep d ":" org_commits[d]
          sep = "|"
        }

        # contributor_count is the size of the authors[] array
        contributor_count = 0
        for (a in authors) { contributor_count++ }

        # Print the CSV line for that day
        print prev_date "," commits "," orgs_str "," added "," deleted "," files "," contributor_count

        # Reset counters
        commits = 0
        files   = 0
        added   = 0
        deleted = 0
        split("", org_commits)
        split("", authors)
      }

      prev_date = commit_date
      commits++

      # parse domain from author_email
      # e.g. "user@microsoft.com" -> "microsoft.com"
      domain = ""
      idx = index(author_email, "@")
      if (idx > 0) {
        domain = substr(author_email, idx+1)
      } else {
        domain = author_email
      }

      if (domain != "") {
        if (! (domain in org_commits)) {
          org_commits[domain] = 0
        }
        org_commits[domain]++
      }

      # track unique author
      authors[author_email] = 1
      next
    }

    # numstat lines match: "<added>\t<deleted>\t<filename>"
    # e.g. "12    4    file/path"
    /^[0-9]+\t[0-9]+\t/ {
      added   += $1
      deleted += $2
      files++
      next
    }

    END {
      # Output the last day if we have one
      if (prev_date != "") {
        orgs_str = ""
        sep = ""
        for (d in org_commits) {
          orgs_str = orgs_str sep d ":" org_commits[d]
          sep = "|"
        }

        contributor_count = 0
        for (a in authors) { contributor_count++ }

        print prev_date "," commits "," orgs_str "," added "," deleted "," files "," contributor_count
      }
    }
  ' | sort -u
}

# update_csv <csv_file> <stats_file>
# Merges new daily stats into the existing CSV (no duplicates).
update_csv() {
  local csv_file="$1"
  local stats_file="$2"

  # If CSV doesn't exist, create with header
  if [ ! -f "$csv_file" ]; then
    echo "date,commits,orgs,lines_added,lines_deleted,files_changed,contributors" > "$csv_file"
  fi

  if [ ! -s "$stats_file" ]; then
    echo "No new stats to add" >&2
    return 0
  fi

  # Gather new dates
  cut -d, -f1 "$stats_file" > "${stats_file}.dates"

  # We'll build a temp file for merged output
  local temp_file="${csv_file}.tmp"

  # Keep the header
  head -1 "$csv_file" > "$temp_file"

  # Keep existing lines that aren't in the new set of dates
  grep -v -f "${stats_file}.dates" "$csv_file" | grep -v "^date" >> "$temp_file"

  # Add the new stats
  cat "$stats_file" >> "$temp_file"

  # Sort by date (keeping the header at top)
  (head -1 "$temp_file"; tail -n +2 "$temp_file" | sort) > "${temp_file}.sorted"

  # Replace original file
  mv "${temp_file}.sorted" "$csv_file"
  rm -f "$temp_file" "${stats_file}.dates"

  echo "CSV file updated successfully" >&2
  return 0
}
