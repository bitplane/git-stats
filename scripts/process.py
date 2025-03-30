#!/usr/bin/env python3
import sys
import csv
from collections import defaultdict
from datetime import datetime
import email.utils

def parse_git_log(log_lines):
    """
    Parse git log input and aggregate daily statistics.
    
    Input format expected:
    COMMIT <hash> <YYYY-MM-DD> <author-email>
    <added>\t<deleted>\t<filename>
    ...
    COMMIT <hash> <YYYY-MM-DD> <author-email>
    ...
    """
    daily_stats = defaultdict(lambda: {
        'commits': 0,
        'lines_added': 0,
        'lines_deleted': 0,
        'files_changed': 0,
        'contributors': set(),
        'orgs': defaultdict(int)
    })
    
    current_date = None
    current_author = None
    
    for line in log_lines:
        line = line.strip()
        
        # Commit line
        if line.startswith('COMMIT'):
            _, _, date, author = line.split(' ', 3)
            current_date = date
            current_author = author
            
            # Extract domain from email
            try:
                _, domain = email.utils.parseaddr(author)[1].split('@')
            except (ValueError, IndexError):
                domain = 'unknown'
            
            # Update daily stats
            day_stats = daily_stats[current_date]
            day_stats['commits'] += 1
            day_stats['contributors'].add(current_author)
            day_stats['orgs'][domain] += 1
        
        # Numstat line (added\tdeleted\tfilename)
        elif '\t' in line:
            try:
                added, deleted, _ = line.split('\t')
                added = int(added)
                deleted = int(deleted)
                
                day_stats = daily_stats[current_date]
                day_stats['lines_added'] += added
                day_stats['lines_deleted'] += deleted
                day_stats['files_changed'] += 1
            except (ValueError, TypeError):
                # Skip malformed lines
                continue
    
    # Convert set of contributors to count
    for day_data in daily_stats.values():
        day_data['contributors'] = len(day_data['contributors'])
        
        # Convert orgs to formatted string
        orgs = '|'.join(f"{org}:{count}" for org, count in day_data['orgs'].items())
        day_data['orgs'] = orgs
    
    return daily_stats

def write_csv(stats, output_file):
    """Write daily stats to CSV."""
    fieldnames = [
        'date', 'commits', 'orgs', 
        'lines_added', 'lines_deleted', 
        'files_changed', 'contributors'
    ]
    
    # Sort stats by date
    sorted_stats = sorted(
        (dict(date=date, **data) for date, data in stats.items()), 
        key=lambda x: x['date']
    )
    
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(sorted_stats)

def main():
    # Read from stdin
    log_lines = sys.stdin.readlines()
    
    # Parse log lines
    daily_stats = parse_git_log(log_lines)
    
    # Write to CSV
    write_csv(daily_stats, sys.argv[1] if len(sys.argv) > 1 else '-')

if __name__ == '__main__':
    main()