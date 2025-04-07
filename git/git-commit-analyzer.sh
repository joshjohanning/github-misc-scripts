#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: git-commit-analyzer.sh
# Description: This script analyzes the size of a specific Git commit.
#              It calculates the total size of all files in the commit, the
#              number of files modified, and provides a detailed breakdown of
#              file sizes. The results are displayed in a human-readable format.
#
# Usage:       ./git-commit-analyzer.sh <commit-hash>
#
# Features:
#   - Verifies if the script is run inside a valid Git repository.
#   - Checks if the specified commit hash exists in the repository.
#   - Calculates the total size of all files in the commit.
#   - Displays the size of each file in the commit in a sorted, descending order.
#   - Formats file sizes for readability (bytes, KB, MB).
#   - Handles the initial commit by comparing it to an empty tree.
#
# Requirements:
#   - Must be run from within a valid Git repository.
#   - Requires a valid commit hash to be passed as an argument.
#
# Output:
#   - A detailed breakdown of file sizes in the specified commit.
#   - Total number of files and the total size of the commit.
#
# Example:
#   ./git-commit-analyzer.sh abc1234
#   This will analyze the commit with hash `abc1234` and display the size of
#   each file in the commit, along with the total size and file count.
#
# Author:      Mickey Gousset (@mickeygousset)
# Date:        2025-04-05
# -----------------------------------------------------------------------------

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <commit-hash>"
    exit 1
fi

COMMIT=$1

# Verify this is a valid git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Verify the commit exists
if ! git cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
    echo "Error: Commit $COMMIT does not exist"
    exit 1
fi

echo "Analyzing commit: $COMMIT"
echo "------------------------"

# Get the parent commit
PARENT=$(git rev-parse "$COMMIT^" 2>/dev/null || echo "")

# If there's no parent (first commit), we'll compare with empty tree
if [ -z "$PARENT" ]; then
    PARENT=$(git hash-object -t tree /dev/null)
    echo "This is the initial commit. Comparing with empty tree."
fi

# Get the list of files changed in this commit
FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT")

# Create a temporary file to store file sizes for sorting
TEMP_FILE=$(mktemp)

# Process each file
while IFS= read -r file; do
    # Get the file blob from the commit
    BLOB=$(git ls-tree -r "$COMMIT" -- "$file" 2>/dev/null | awk '{print $3}')
    
    if [ -n "$BLOB" ]; then
        # Get the size of the blob
        SIZE=$(git cat-file -s "$BLOB")
        
        # Add to temp file with size and filename
        echo "$SIZE $file" >> "$TEMP_FILE"
    fi
done <<< "$FILES"

# Calculate total size and count
TOTAL_SIZE=0
FILE_COUNT=0

# Print header
printf "%-60s %15s\n" "FILE" "SIZE"
printf "%-60s %15s\n" "----" "----"

# Sort by size (numerically, descending) and display
while read -r SIZE file; do
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    FILE_COUNT=$((FILE_COUNT + 1))
    
    # Format size for human readability
    if [ "$SIZE" -gt 1048576 ]; then
        FORMATTED_SIZE=$(echo "scale=2; $SIZE/1048576" | bc)" MB"
    elif [ "$SIZE" -gt 1024 ]; then
        FORMATTED_SIZE=$(echo "scale=2; $SIZE/1024" | bc)" KB"
    else
        FORMATTED_SIZE="$SIZE bytes"
    fi
    
    # Print file with size
    printf "%-60s %15s\n" "$file" "$FORMATTED_SIZE"
    
done < <(sort -nr "$TEMP_FILE")

# Clean up temp file
rm "$TEMP_FILE"

# Print total
if [ "$TOTAL_SIZE" -gt 1048576 ]; then
    TOTAL_FORMATTED=$(echo "scale=2; $TOTAL_SIZE/1048576" | bc)" MB"
elif [ "$TOTAL_SIZE" -gt 1024 ]; then
    TOTAL_FORMATTED=$(echo "scale=2; $TOTAL_SIZE/1024" | bc)" KB"
else
    TOTAL_FORMATTED="$TOTAL_SIZE bytes"
fi

echo "------------------------"
echo "Total files: $FILE_COUNT"
echo "Total size: $TOTAL_FORMATTED"