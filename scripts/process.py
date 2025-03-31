#!/usr/bin/env python3
import sys
import csv
import os
from collections import defaultdict

def get_org(email):
    """Extract organization name from email address.
    Example: whoever@microsoft.com -> microsoft
    """
    try:
        # Get the domain part after @
        domain = email.split('@')[1]
        # Return just the first part of the domain (before first .)
        return domain.split('.')[0]
    except (IndexError, AttributeError):
        return 'unknown'

def is_commit_line(line):
    """Check if line is a commit line."""
    return line.startswith('COMMIT')

def is_file_line(line):
    """Check if line is a file stats line."""
    return '\t' in line

def remove_last_line(filename):
    """Remove the last line from a CSV file."""
    if not os.path.exists(filename):
        return

    # Read all lines except the last
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    if not lines:
        return

    # Write all lines except the last
    with open(filename, 'w') as f:
        f.writelines(lines[:-1])

def commit_stats_generator():
    """
    Generator that yields commit statistics from stdin.
    """
    # Use defaultdict to accumulate stats across commits on the same date
    current_stats = defaultdict(lambda: {
        'lines_added': 0,
        'lines_deleted': 0,
        'files_changed': 0,
        'orgs': defaultdict(int)
    })

    current_date = None
    author_org = None  # Initialize author_org at the function level

    for line in sys.stdin:
        line = line.strip()

        # Commit line
        if is_commit_line(line):
            # Parse new commit
            parts = line.split()
            if len(parts) < 3:
                print(f"Warning: Malformed commit line: {line}", file=sys.stderr)
                continue

            # Parsing commit details
            _, commit_hash, date = parts[:3]
            author = parts[3] if len(parts) > 3 else "unknown@unknown.com"
            
            # If date changes, yield previous date's stats
            if current_date and current_date != date:
                # Prepare and yield each unique combination of date and org
                for org, org_count in current_stats[current_date]['orgs'].items():
                    yield {
                        'date': current_date,
                        'commits': 1,
                        'orgs': f'{org}:{org_count}',
                        'lines_added': current_stats[current_date]['lines_added'],
                        'lines_deleted': current_stats[current_date]['lines_deleted'],
                        'files_changed': current_stats[current_date]['files_changed'],
                        'contributors': 1  # Always 1 commit per line
                    }
                
                # Reset stats for new date
                current_stats[date] = {
                    'lines_added': 0,
                    'lines_deleted': 0,
                    'files_changed': 0,
                    'orgs': defaultdict(int)
                }

            current_date = date
            author_org = get_org(author)
            # Initialize org count for this commit
            current_stats[current_date]['orgs'][author_org] += 1

        # File stats line
        elif current_date and is_file_line(line):
            try:
                added, deleted, filename = line.split('\t')
                # Convert '-' to 0 for binary files
                added_lines = int(added) if added != '-' else 0
                deleted_lines = int(deleted) if deleted != '-' else 0
                
                current_stats[current_date]['lines_added'] += added_lines
                current_stats[current_date]['lines_deleted'] += deleted_lines
                current_stats[current_date]['files_changed'] += 1
            except (ValueError, TypeError) as e:
                print(f"Warning: Malformed file stats line: {line} ({e})", file=sys.stderr)

    # Yield final date's stats
    if current_date:
        for org, org_count in current_stats[current_date]['orgs'].items():
            yield {
                'date': current_date,
                'commits': 1,
                'orgs': f'{org}:{org_count}',
                'lines_added': current_stats[current_date]['lines_added'],
                'lines_deleted': current_stats[current_date]['lines_deleted'],
                'files_changed': current_stats[current_date]['files_changed'],
                'contributors': 1  # Always 1 commit per line
            }

def main():
    if len(sys.argv) < 2:
        print("Usage: process.py <output_csv>", file=sys.stderr)
        sys.exit(1)

    output_csv = sys.argv[1]

    # Remove last line from existing CSV
    remove_last_line(output_csv)

    # Prepare CSV file
    fieldnames = [
        'date', 'commits', 'orgs', 
        'lines_added', 'lines_deleted', 
        'files_changed', 'contributors'
    ]

    # Open CSV for appending
    file_exists = os.path.exists(output_csv) and os.path.getsize(output_csv) > 0
    with open(output_csv, 'a', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        # Write headers if file is empty
        if not file_exists:
            writer.writeheader()

        # Write new stats
        for stats in commit_stats_generator():
            writer.writerow(stats)

if __name__ == '__main__':
    main()