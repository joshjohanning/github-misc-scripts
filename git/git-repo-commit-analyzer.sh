#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: git-repo-commit-analyzer.sh
# Description: This script analyzes the size of all commits in a Git repository.
#              It generates detailed logs, CSV reports, and exception logs for
#              commits that meet or exceed a specified size threshold.
#
# Usage:       ./git-repo-commit-analyzer.sh <size-threshold-in-bytes>
#
# Features:
#   - Analyzes all commits in the current Git repository.
#   - Calculates the total size of each commit and the number of files it modifies.
#   - Generates the following output files:
#       1. A log file with detailed analysis of all commits.
#       2. A CSV file summarizing commit hash, size, and file count.
#       3. An exceptions log file for commits exceeding the size threshold, 
#          including detailed file sizes for each commit.
#   - Identifies and logs the largest commit in the repository.
#
# Requirements:
#   - Must be run from within a valid Git repository.
#   - Requires a size threshold (in bytes) to be passed as an argument.
#
# Output Files:
#   - <repo-name>-analyzer-<timestamp>.log
#   - <repo-name>-commits-size-<timestamp>.csv
#   - <repo-name>-commit-size-exceptions-<timestamp>.log
#
# Example:
#   ./git-repo-commit-analyzer.sh 100000
#   This will analyze all commits in the repository and log details for commits
#   with a total size of 100,000 bytes or more.
#
# Author:      Mickey Gousset (@mickeygousset)
# Date:        2025-04-05
# -----------------------------------------------------------------------------

set -e

# Verify this is a valid git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get the repository name
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

# Check if a size threshold is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <size-threshold-in-bytes>"
    exit 1
fi

SIZE_THRESHOLD=$1

# Generate timestamp for log and CSV filenames
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="${REPO_NAME}-analyzer-$TIMESTAMP.log"
CSV_FILE="${REPO_NAME}-commits-size-$TIMESTAMP.csv"
EXCEPTIONS_FILE="${REPO_NAME}-commit-size-exceptions-$TIMESTAMP.log"

# Initialize variables to track the largest commit
LARGEST_COMMIT=""
LARGEST_SIZE=0

# Create the CSV file and add the header
echo "Commit Hash,Commit Size (bytes),Number of Files" > "$CSV_FILE"

# Create the exceptions file
echo "Commits meeting or exceeding the size threshold ($SIZE_THRESHOLD bytes) in repository '$REPO_NAME':" > "$EXCEPTIONS_FILE"

# Function to log output to both the screen and the log file
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to log exceptions to the exceptions file
log_exception() {
    echo "$1" | tee -a "$EXCEPTIONS_FILE"
}

# Array to store commits that meet the size threshold
declare -a LARGE_COMMITS

# Loop through all commits in the repository
for COMMIT in $(git rev-list --all); do
    log "Analyzing commit: $COMMIT in repository '$REPO_NAME'"
    log "------------------------"

    # Get the parent commit
    PARENT=$(git rev-parse "$COMMIT^" 2>/dev/null || echo "")

    # If there's no parent (first commit), compare with empty tree
    if [ -z "$PARENT" ]; then
        PARENT=$(git hash-object -t tree /dev/null)
        log "This is the initial commit. Comparing with empty tree."
    fi

    # Get the list of files changed in this commit
    FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT" 2>/dev/null || echo "")

    if [ -z "$FILES" ]; then
        log "No files changed in this commit."
        continue
    fi

    # Create a temporary file to store file sizes for sorting
    TEMP_FILE=$(mktemp)

    # Process each file
    while IFS= read -r file; do
        # Get the file blob from the commit
        BLOB=$(git ls-tree -r "$COMMIT" -- "$file" 2>/dev/null | awk '{print $3}')
        
        if [ -n "$BLOB" ]; then
            # Get the size of the blob
            SIZE=$(git cat-file -s "$BLOB" 2>/dev/null || echo "0")
            
            if [ "$SIZE" -gt 0 ]; then
                # Add to temp file with size and filename
                echo "$SIZE $file" >> "$TEMP_FILE"
            fi
        fi
    done <<< "$FILES"

    # Calculate total size and count
    TOTAL_SIZE=0
    FILE_COUNT=0

    if [ -s "$TEMP_FILE" ]; then
        # Sort by size (numerically, descending) and calculate totals
        while read -r SIZE file; do
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
            FILE_COUNT=$((FILE_COUNT + 1))
        done < <(sort -nr "$TEMP_FILE")
    fi

    # Clean up temp file
    rm "$TEMP_FILE"

    # Log total for this commit
    log "Total files: $FILE_COUNT"
    log "Total size: $TOTAL_SIZE bytes"
    log "------------------------"

    # Append commit details to the CSV file
    echo "$COMMIT,$TOTAL_SIZE,$FILE_COUNT" >> "$CSV_FILE"

    # Check if this is the largest commit
    if [ "$TOTAL_SIZE" -gt "$LARGEST_SIZE" ]; then
        LARGEST_SIZE=$TOTAL_SIZE
        LARGEST_COMMIT=$COMMIT
    fi

    # Check if the commit meets the size threshold
    if [ "$TOTAL_SIZE" -ge "$SIZE_THRESHOLD" ]; then
        LARGE_COMMITS+=("$COMMIT ($TOTAL_SIZE bytes)")

        # Log details to the exceptions file
        log_exception "Commit: $COMMIT"
        log_exception "Total Size: $TOTAL_SIZE bytes"
        log_exception "Files:"
        
        # Log each file and its size
        while IFS= read -r file; do
            BLOB=$(git ls-tree -r "$COMMIT" -- "$file" 2>/dev/null | awk '{print $3}')
            if [ -n "$BLOB" ]; then
                SIZE=$(git cat-file -s "$BLOB" 2>/dev/null || echo "0")
                log_exception "  $file: $SIZE bytes"
            fi
        done <<< "$FILES"
        
        log_exception "------------------------"
    fi
done

# Output the largest commit
log "Largest commit: $LARGEST_COMMIT"
log "Largest size: $LARGEST_SIZE bytes"

# Output commits that meet the size threshold
if [ ${#LARGE_COMMITS[@]} -gt 0 ]; then
    log "Commits meeting or exceeding the size threshold ($SIZE_THRESHOLD bytes):"
    for COMMIT_INFO in "${LARGE_COMMITS[@]}"; do
        log "$COMMIT_INFO"
    done
else
    log "No commits meet or exceed the size threshold ($SIZE_THRESHOLD bytes)."
fi

log "Log file created: $LOG_FILE"
log "CSV file created: $CSV_FILE"
log "Exceptions file created: $EXCEPTIONS_FILE"