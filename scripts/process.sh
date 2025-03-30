#!/bin/bash
# process.sh - Functions for processing git log data into stats

# Process git log data into daily stats
# Usage: process_log_data
process_log_data() {
  awk '
    BEGIN { 
      date=""; 
      commits=0; 
      files=0; 
      added=0; 
      deleted=0;
      prev_date="";
    }
    
    /^COMMIT/ { 
      # New commit found, extract date
      date=$3
      
      # If date changes, output stats for previous date
      if (prev_date != "" && date != prev_date) {
        print prev_date "," commits ",," added "," deleted "," files
        # Reset counters for new date
        commits=0; files=0; added=0; deleted=0;
      }
      
      # Update for current commit
      prev_date = date
      commits++
    }
    
    /^[0-9]+\t[0-9]+\t/ { 
      # Count stats from file changes
      added += $1
      deleted += $2
      files++
    }
    
    END {
      # Output stats for last date
      if (prev_date != "") {
        print prev_date "," commits ",," added "," deleted "," files
      }
    }
  ' | sort -u
}

# Update CSV file with new stats, avoiding duplicates
# Usage: update_csv <csv-file> <stats-file>
update_csv() {
  local csv_file="$1"
  local stats_file="$2"
  
  # Create CSV with header if it doesn't exist
  if [ ! -f "$csv_file" ]; then
    echo "date,commits,orgs,lines_added,lines_deleted,files_changed" > "$csv_file"
  fi
  
  # Check if we have new stats
  if [ ! -s "$stats_file" ]; then
    echo "No new stats to add" >&2
    return 0
  fi
  
  # Get all dates from the new stats
  cut -d, -f1 "$stats_file" > "${stats_file}.dates"
  
  # Create a temporary file for the merge
  local temp_file="${csv_file}.tmp"
  
  # Keep the header
  head -1 "$csv_file" > "$temp_file"
  
  # Add all lines from the CSV that don't match new dates
  if [ -s "$csv_file" ]; then
    grep -v -f "${stats_file}.dates" "$csv_file" | grep -v "^date" >> "$temp_file"
  fi
  
  # Add the new stats
  cat "$stats_file" >> "$temp_file"
  
  # Sort by date (keeping header at top)
  (head -1 "$temp_file"; tail -n +2 "$temp_file" | sort) > "${temp_file}.sorted"
  
  # Replace the original file
  mv "${temp_file}.sorted" "$csv_file"
  
  # Clean up temporary files
  rm -f "$temp_file" "${stats_file}.dates"
  
  echo "CSV file updated successfully" >&2
  return 0
}