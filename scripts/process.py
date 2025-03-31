#!/usr/bin/env python3
import sys
import csv
import os
from collections import defaultdict

# Force stdout and stderr to flush immediately
# Use Python 3.7+ method if available, fallback for older versions
try:
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)
except AttributeError:
    # For older Python versions
    sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)
    sys.stderr = os.fdopen(sys.stderr.fileno(), 'w', buffering=1)


def get_org(email):
    """Extract organization name from email address.
    Examples:
    - whoever@microsoft.com -> microsoft
    - johndoe (no @) -> johndoe
    - unknown/empty -> unknown
    """
    if not email or email == "":
        return 'unknown'
        
    try:
        if '@' in email:
            # Standard email: extract domain part
            domain = email.split('@')[1]
            # Return just the first part of the domain (before first .)
            return domain.split('.')[0]
        else:
            # No @ sign, use the username as the org
            # Clean up common suffixes that might appear in usernames
            username = email.strip()
            # Remove potential trailing items like "(no author)" etc.
            if "(" in username:
                username = username.split("(")[0].strip()
            return username if username else 'unknown'
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
    Collects all stats and yields them sorted by date at the end.
    """
    # Use defaultdict to accumulate stats across commits on the same date
    stats_by_date = defaultdict(lambda: {
        'commits': 0,
        'lines_added': 0,
        'lines_deleted': 0,
        'files_changed': 0,
        'contributors': 0,
        'orgs': defaultdict(int)
    })

    current_date = None
    current_month = None
    
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
            
            # Check if we've moved to a new month
            month = date[:7]  # Extract YYYY-MM portion
            if month != current_month:
                if current_month is not None:
                    print(f"Processing month: {month}", file=sys.stderr)
                current_month = month
            
            # Update current date
            current_date = date
            
            # Update commit count and contributor count
            stats_by_date[current_date]['commits'] += 1
            stats_by_date[current_date]['contributors'] += 1
            
            # Update org stats
            author_org = get_org(author)
            stats_by_date[current_date]['orgs'][author_org] += 1

        # File stats line
        elif current_date and is_file_line(line):
            try:
                added, deleted, filename = line.split('\t')
                # Convert '-' to 0 for binary files
                added_lines = int(added) if added != '-' else 0
                deleted_lines = int(deleted) if deleted != '-' else 0
                
                stats_by_date[current_date]['lines_added'] += added_lines
                stats_by_date[current_date]['lines_deleted'] += deleted_lines
                stats_by_date[current_date]['files_changed'] += 1
            except (ValueError, TypeError) as e:
                print(f"Warning: Malformed file stats line: {line} ({e})", file=sys.stderr)

    # Process all dates in chronological order
    print(f"Processing complete. Yielding {len(stats_by_date)} dates in chronological order...", file=sys.stderr)
    for date in sorted(stats_by_date.keys()):
        stats = stats_by_date[date]
        # Format orgs as "org1:count|org2:count|..."
        orgs_formatted = '|'.join(f"{org}:{count}" for org, count in stats['orgs'].items())
        
        yield {
            'date': date,
            'commits': stats['commits'],
            'orgs': orgs_formatted,
            'lines_added': stats['lines_added'],
            'lines_deleted': stats['lines_deleted'],
            'files_changed': stats['files_changed'],
            'contributors': stats['contributors']
        }# Parse new commit
            parts = line.split()
            if len(parts) < 3:
                print(f"Warning: Malformed commit line: {line}", file=sys.stderr)
                continue

            # Parsing commit details
            _, commit_hash, date = parts[:3]
            author = parts[3] if len(parts) > 3 else "unknown@unknown.com"
            
            # Check if we've moved to a new month
            month = date[:7]  # Extract YYYY-MM portion
            if month != current_month:
                if current_month is not None:
                    print(f"Processing month: {month}", file=sys.stderr)
                current_month = month
            
            # Check if we're moving to a new date
            if current_date is not None and current_date != date:
                # Yield the completed day before moving to the next
                stats = stats_by_date[current_date]
                # Format orgs as "org1:count|org2:count|..."
                orgs_formatted = '|'.join(f"{org}:{count}" for org, count in stats['orgs'].items())
                
                yield {
                    'date': current_date,
                    'commits': stats['commits'],
                    'orgs': orgs_formatted,
                    'lines_added': stats['lines_added'],
                    'lines_deleted': stats['lines_deleted'],
                    'files_changed': stats['files_changed'],
                    'contributors': stats['contributors']
                }
                # Remove yielded date from the dict to save memory
                del stats_by_date[current_date]
            
            # Update current date
            current_date = date
            
            # Update commit count and contributor count
            stats_by_date[current_date]['commits'] += 1
            stats_by_date[current_date]['contributors'] += 1
            
            # Update org stats
            author_org = get_org(author)
            stats_by_date[current_date]['orgs'][author_org] += 1

        # File stats line
        elif current_date and is_file_line(line):
            try:
                added, deleted, filename = line.split('\t')
                # Convert '-' to 0 for binary files
                added_lines = int(added) if added != '-' else 0
                deleted_lines = int(deleted) if deleted != '-' else 0
                
                stats_by_date[current_date]['lines_added'] += added_lines
                stats_by_date[current_date]['lines_deleted'] += deleted_lines
                stats_by_date[current_date]['files_changed'] += 1
            except (ValueError, TypeError) as e:
                print(f"Warning: Malformed file stats line: {line} ({e})", file=sys.stderr)

    # Yield any remaining stats
    for date, stats in sorted(stats_by_date.items()):
        # Format orgs as "org1:count|org2:count|..."
        orgs_formatted = '|'.join(f"{org}:{count}" for org, count in stats['orgs'].items())
        
        yield {
            'date': date,
            'commits': stats['commits'],
            'orgs': orgs_formatted,
            'lines_added': stats['lines_added'],
            'lines_deleted': stats['lines_deleted'],
            'files_changed': stats['files_changed'],
            'contributors': stats['contributors']
        }

def main():
    if len(sys.argv) < 2:
        print("Usage: process.py <output_csv>", file=sys.stderr)
        sys.exit(1)

    output_csv = sys.argv[1]
    cache_dir = os.path.dirname(os.path.dirname(output_csv)) + "/.cache"
    
    # Extract repo name from output path
    repo_name = os.path.basename(output_csv).replace('.csv', '')
    temp_csv = f"{cache_dir}/{repo_name}_temp.csv"
    
    # Ensure cache directory exists
    os.makedirs(cache_dir, exist_ok=True)
    
    # Define fieldnames for both raw and final CSVs
    raw_fieldnames = [
        'hash', 'date', 'org', 
        'lines_added', 'lines_deleted', 
        'files_changed'
    ]
    
    final_fieldnames = [
        'date', 'commits', 'orgs', 
        'lines_added', 'lines_deleted', 
        'files_changed', 'contributors'
    ]
    
    # First phase: Stream raw commit data to temp file
    print(f"Phase 1: Streaming raw commit data to {temp_csv}", file=sys.stderr)
    
    # Create or truncate temp file
    with open(temp_csv, 'w', newline='', buffering=1) as temp_file:
        temp_writer = csv.DictWriter(temp_file, fieldnames=raw_fieldnames)
        temp_writer.writeheader()
        
        current_hash = None
        current_date = None
        current_org = None
        lines_added = 0
        lines_deleted = 0
        files_changed = 0
        
        # Track the last hash we've seen
        latest_hash = None
        
        for line in sys.stdin:
            line = line.strip()
            
            # Commit line
            if is_commit_line(line):
                # Before moving to a new commit, write the current one if it exists
                if current_hash is not None:
                    temp_writer.writerow({
                        'hash': current_hash,
                        'date': current_date,
                        'org': current_org,
                        'lines_added': lines_added,
                        'lines_deleted': lines_deleted,
                        'files_changed': files_changed
                    })
                    temp_file.flush()
                
                # Parse new commit
                parts = line.split()
                if len(parts) < 3:
                    print(f"Warning: Malformed commit line: {line}", file=sys.stderr)
                    continue
                
                # Reset counters for the new commit
                _, commit_hash, date = parts[:3]
                author = parts[3] if len(parts) > 3 else "unknown@unknown.com"
                
                current_hash = commit_hash
                current_date = date
                current_org = get_org(author)
                lines_added = 0
                lines_deleted = 0
                files_changed = 0
                
                # Update latest hash
                latest_hash = commit_hash
                
                # Check if we've moved to a new month
                month = date[:7]  # Extract YYYY-MM portion
                print(f"Processing: {date} ({current_org})", file=sys.stderr)
            
            # File stats line
            elif current_hash and is_file_line(line):
                try:
                    added, deleted, filename = line.split('\t')
                    # Convert '-' to 0 for binary files
                    added_lines = int(added) if added != '-' else 0
                    deleted_lines = int(deleted) if deleted != '-' else 0
                    
                    lines_added += added_lines
                    lines_deleted += deleted_lines
                    files_changed += 1
                except (ValueError, TypeError) as e:
                    print(f"Warning: Malformed file stats line: {line} ({e})", file=sys.stderr)
        
        # Write final commit if there was one
        if current_hash is not None:
            temp_writer.writerow({
                'hash': current_hash,
                'date': current_date,
                'org': current_org,
                'lines_added': lines_added,
                'lines_deleted': lines_deleted,
                'files_changed': files_changed
            })
    
    # Save latest hash for future runs
    if latest_hash:
        latest_file = os.path.join(os.path.dirname(output_csv), f"{repo_name}.latest")
        with open(latest_file, 'w') as f:
            f.write(latest_hash)
    
    # Phase 2: Consolidate temp data into final output
    print(f"Phase 2: Consolidating data to {output_csv}", file=sys.stderr)
    
    # Load existing final CSV data to avoid duplication
    existing_data = {}
    if os.path.exists(output_csv):
        try:
            with open(output_csv, 'r', newline='') as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    existing_data[row['date']] = row
        except Exception as e:
            print(f"Warning: Error reading existing CSV: {e}", file=sys.stderr)
    
    # Process temp data and consolidate by date
    consolidated = {}
    with open(temp_csv, 'r', newline='') as temp_file:
        reader = csv.DictReader(temp_file)
        for row in reader:
            date = row['date']
            org = row['org']
            
            if date not in consolidated:
                consolidated[date] = {
                    'date': date,
                    'commits': 0,
                    'orgs': {},
                    'lines_added': 0,
                    'lines_deleted': 0,
                    'files_changed': 0,
                    'contributors': 0
                }
            
            # Update stats
            consolidated[date]['commits'] += 1
            consolidated[date]['lines_added'] += int(row['lines_added'])
            consolidated[date]['lines_deleted'] += int(row['lines_deleted'])
            consolidated[date]['files_changed'] += int(row['files_changed'])
            consolidated[date]['contributors'] += 1
            
            # Update org count
            if org in consolidated[date]['orgs']:
                consolidated[date]['orgs'][org] += 1
            else:
                consolidated[date]['orgs'][org] = 1
    
    # Merge with existing data
    for date, existing_row in existing_data.items():
        if date not in consolidated:
            # Keep existing data if we don't have new data for this date
            consolidated[date] = existing_row
        else:
            # Already have new data, check if we need to merge orgs
            if 'orgs' in existing_row and existing_row['orgs']:
                try:
                    # Parse existing orgs string
                    existing_orgs = {}
                    for org_item in existing_row['orgs'].split('|'):
                        if ':' in org_item:
                            org_name, count = org_item.split(':')
                            existing_orgs[org_name] = int(count)
                    
                    # Merge with new orgs
                    for org, count in existing_orgs.items():
                        if org in consolidated[date]['orgs']:
                            consolidated[date]['orgs'][org] += count
                        else:
                            consolidated[date]['orgs'][org] = count
                except Exception as e:
                    print(f"Warning: Error parsing existing orgs: {e}", file=sys.stderr)
    
    # Write consolidated data to final CSV
    with open(output_csv, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=final_fieldnames)
        writer.writeheader()
        
        # Sort by date and write
        for date in sorted(consolidated.keys()):
            stats = consolidated[date]
            
            # Format orgs as "org1:count|org2:count|..."
            if isinstance(stats['orgs'], dict):
                orgs_formatted = '|'.join(f"{org}:{count}" for org, count in stats['orgs'].items())
                stats['orgs'] = orgs_formatted
            
            writer.writerow(stats)
    
    print(f"✅ Successfully processed data for {repo_name}", file=sys.stderr)
    
    # Optional cleanup
    # os.remove(temp_csv)

if __name__ == '__main__':
    main()