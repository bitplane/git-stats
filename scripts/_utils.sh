#!/bin/bash
# scripts/_utils.sh
# Misc helper functions

# get_last_date <csv-file> [default-date]
#  returns the most recent date in the CSV, or the default if file is empty.
get_last_date() {
  local csv_file="$1"
  local default_date="${2:-0001-01-01}"
  local today
  today=$(date -u +"%Y-%m-%d")

  if [ -f "$csv_file" ] && [ -s "$csv_file" ]; then
    # Skip header, parse only lines that begin with YYYY-MM-DD
    local dates
    dates=$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' "$csv_file" | cut -d, -f1)
    if [ -n "$dates" ]; then
      local last_date
      last_date=$(echo "$dates" | sort -r | head -n1)

      # If that last_date is in the future, fallback to today
      if [[ "$last_date" > "$today" ]]; then
        echo "Warning: Found future date in $csv_file ($last_date), using $today instead." >&2
        echo "$today"
      else
        echo "$last_date"
      fi
    else
      echo "$default_date"
    fi
  else
    echo "$default_date"
  fi
}

# Check if a string is a valid YYYY-MM-DD
is_valid_date() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

# ensure_dir <dirname>
ensure_dir() {
  local dir="$1"
  [ -d "$dir" ] || mkdir -p "$dir"
}
