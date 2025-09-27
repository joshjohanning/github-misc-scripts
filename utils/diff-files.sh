#!/bin/bash

# diff-files.sh - Find differences between two files
# 
# Usage: 
#   ./diff-files.sh file1 file2                    # Compare two files (output to stdout)
#   ./diff-files.sh file1 file2 --output diff.txt  # Save output to file
#   ./diff-files.sh file1 file2 | grep "+"         # Pipe output to other commands
#   ./diff-files.sh --help                         # Show this help
#
# The script outputs the diff to stdout by default for maximum flexibility

set -e

# Function to show usage
show_usage() {
  echo "Usage: $0 <file1> <file2> [options]"
  echo ""
  echo "Options:"
  echo "  --output FILE    Save output to specified file instead of stdout"
  echo "  --help           Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 old.txt new.txt                    # Output to stdout"
  echo "  $0 old.txt new.txt --output diff.txt  # Save to file"
  echo "  $0 old.txt new.txt | grep \"+\"         # Pipe to other commands"
}



# Parse arguments
OUTPUT_FILE=""
FILE1=""
FILE2=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      if [[ -z "$FILE1" ]]; then
        FILE1="$1"
      elif [[ -z "$FILE2" ]]; then
        FILE2="$1"
      else
        echo "Error: Too many arguments"
        show_usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Check if we have both files
if [[ -z "$FILE1" ]] || [[ -z "$FILE2" ]]; then
  echo "Error: Please provide two files to compare"
  echo ""
  show_usage
  exit 1
fi

# Check if files exist
if [[ ! -f "$FILE1" ]]; then
  echo "Error: File '$FILE1' does not exist"
  exit 1
fi

if [[ ! -f "$FILE2" ]]; then
  echo "Error: File '$FILE2' does not exist"
  exit 1
fi

# Generate diff and extract only the actual differences (+ and - lines)
DIFF_OUTPUT=$(diff -u "$FILE1" "$FILE2" 2>/dev/null || true)

# Check if files are identical
if [[ -z "$DIFF_OUTPUT" ]]; then
  echo "No differences found." >&2
else
  # Filter to only show lines that were added (+) or removed (-)
  # Skip the header lines (---, +++, @@)
  FILTERED_DIFF=$(echo "$DIFF_OUTPUT" | grep -E "^[+-][^+-]")
  
  if [[ -n "$FILTERED_DIFF" ]]; then
    LINE_COUNT=$(echo "$FILTERED_DIFF" | wc -l | tr -d ' ')
    
    if [[ -n "$OUTPUT_FILE" ]]; then
      echo "$FILTERED_DIFF" > "$OUTPUT_FILE"
      echo "Saved $LINE_COUNT lines of differences to $OUTPUT_FILE" >&2
    else
      echo "$FILTERED_DIFF"
      echo "Found $LINE_COUNT lines of differences" >&2
    fi
  else
    echo "No content differences found." >&2
  fi
fi
