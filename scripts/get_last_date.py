#!/usr/bin/env python3
"""Get the most recent date from a CSV file."""

import sys
from datetime import datetime, timedelta
import os.path

def main():
    if len(sys.argv) < 2:
        print("Usage: get_last_date.py <csv_file> [default_date]", file=sys.stderr)
        sys.exit(1)

    csv_file = sys.argv[1]
    default_date = sys.argv[2] if len(sys.argv) > 2 else "1970-01-01"
    today = datetime.now().strftime("%Y-%m-%d")
    
    if not os.path.isfile(csv_file) or os.path.getsize(csv_file) == 0:
        print(default_date)
        return
    
    try:
        with open(csv_file, 'r') as f:
            lines = f.readlines()
        
        # Skip header, extract first column as date, filter out any future dates
        dates = [line.split(',')[0] for line in lines[1:] if line.strip() and line.split(',')[0] < today]
        
        if not dates:
            print(default_date)
            return
            
        # Sort dates in descending order and take the first one
        last_date = sorted(dates, reverse=True)[0]
        
        # Subtract one day
        last_date_obj = datetime.strptime(last_date, "%Y-%m-%d") - timedelta(days=1)
        print(last_date_obj.strftime("%Y-%m-%d"))
    except Exception:
        print(default_date)

if __name__ == "__main__":
    main()