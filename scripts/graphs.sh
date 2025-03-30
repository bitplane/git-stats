#!/bin/bash
# graphs.sh
# Generates SVG graphs from CSV data using gnuplot
# Usage: ./graphs.sh input.csv output_directory/

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <input.csv> <output_directory>"
  exit 1
fi

INPUT_CSV="$1"
OUTPUT_DIR="$2"
REPO_NAME=$(basename "$INPUT_CSV" .csv)

# Ensure gnuplot is installed
command -v gnuplot >/dev/null 2>&1 || { echo "Error: gnuplot is required but not installed. Aborting."; exit 1; }

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Generate commits over time graph
echo "Generating commits graph for $REPO_NAME..."
gnuplot << EOF
set terminal svg size 800,500 enhanced font "sans,10" background rgb 'white'
set output '$OUTPUT_DIR/commits.svg'
set title "Commits over time: $REPO_NAME"
set xlabel "Date"
set ylabel "Commits"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m"
set grid
set key outside right top
set style fill transparent solid 0.5 noborder
set datafile separator ","

# Calculate moving average for trend line
stats '$INPUT_CSV' using 2 nooutput
mavg_window = int(STATS_records / 20 > 7 ? STATS_records / 20 : 7)

# Plot the data
plot '$INPUT_CSV' using 1:2 with impulses lc rgb "#4682B4" title "Daily commits", \
     '$INPUT_CSV' using 1:2 smooth acsplines lc rgb "#A52A2A" lw 2 title "Trend"
EOF

# Generate lines of code (added/deleted) over time
echo "Generating lines of code graph for $REPO_NAME..."
gnuplot << EOF
set terminal svg size 800,500 enhanced font "sans,10" background rgb 'white'
set output '$OUTPUT_DIR/lines.svg'
set title "Code changes over time: $REPO_NAME"
set xlabel "Date"
set ylabel "Lines of code"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m"
set grid
set key outside right top
set style fill transparent solid 0.5 noborder
set datafile separator ","

# Plot the data
plot '$INPUT_CSV' using 1:4 with boxes lc rgb "#228B22" title "Lines added", \
     '$INPUT_CSV' using 1:5 with boxes lc rgb "#CD5C5C" title "Lines deleted", \
     '$INPUT_CSV' using 1:6 with lines lc rgb "#4B0082" lw 2 title "Files changed"
EOF

echo "✅ Graphs generated successfully in $OUTPUT_DIR/"