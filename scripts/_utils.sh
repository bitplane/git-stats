#!/bin/bash
# _utils.sh - Utility functions for the git stats scripts

# Get the last date from a CSV file or return default
# Usage: get_last_date <csv-file> [default-date]
get_last_date() {
  local csv_file="$1"
  local default_date="${2:-0001-01-01}"
  local today=$(date -u +"%Y-%m-%d")
  
  # Check if file exists and has content
  if [ -f "$csv_file" ] && [ -s "$csv_file" ]; then
    # Extract dates, skip header if present
    local dates=$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' "$csv_file" | cut -d, -f1)
    
    if [ -n "$dates" ]; then
      # Get the most recent date
      local last_date=$(echo "$dates" | sort -r | head -n1)
      
      # Check if date is in the future
      if [[ "$last_date" > "$today" ]]; then
        echo "Warning: Found future date in CSV: $last_date, using today instead." >&2
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

# Test if a string is a valid date in YYYY-MM-DD format
is_valid_date() {
  local date_str="$1"
  if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    # Additional validation could be added here
    return 0
  else
    return 1
  fi
}

# Simple function to ensure a directory exists
ensure_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
}