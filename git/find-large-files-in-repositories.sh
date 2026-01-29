#!/bin/bash

# Finds files over a specified size (default: 100MB) across multiple git repositories
# Reads repository URLs from a text file (one URL per line)
#
# Prerequisites:
# - git must be installed
# - For macOS: brew install coreutils (for numfmt/gnumfmt)
#
# Usage:
#   ./find-large-files-in-repositories.sh <repos-file> [size-in-mb]
#
# Example:
#   ./find-large-files-in-repositories.sh repos.txt 100
#
# repos.txt format (one repository URL per line):
#   https://github.com/owner/repo1.git
#   https://github.com/owner/repo2.git
#   git@github.com:owner/repo3.git

if [ -z "$1" ]; then
  echo "Usage: $0 <repos-file> [size-in-mb]"
  echo "  repos-file: Path to a text file containing repository URLs (one per line)"
  echo "  size-in-mb: Minimum file size in MB to report (default: 100)"
  exit 1
fi

REPOS_FILE="$1"
SIZE_MB="${2:-100}"
SIZE_BYTES=$((SIZE_MB * 1048576))

if [ ! -f "$REPOS_FILE" ]; then
  echo "Error: File '$REPOS_FILE' not found"
  exit 1
fi

# Create a temporary directory for clones
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Finding files >= ${SIZE_MB}MB in repositories listed in $REPOS_FILE"
echo "============================================================"
echo ""

while IFS= read -r repo_url || [ -n "$repo_url" ]; do
  # Skip empty lines and comments
  [[ -z "$repo_url" || "$repo_url" =~ ^# ]] && continue

  repo_name=$(basename "$repo_url" .git)
  echo "=== Checking: $repo_name ==="
  echo "    URL: $repo_url"

  clone_path="$TEMP_DIR/$repo_name.git"

  if ! git clone --bare "$repo_url" "$clone_path" 2>/dev/null; then
    echo "    Error: Failed to clone repository"
    echo ""
    continue
  fi

  cd "$clone_path" || continue

  # Find files over the specified size
  large_files=$(git rev-list --objects --all 2>/dev/null | \
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null | \
    awk -v size="$SIZE_BYTES" '/^blob/ && $3 >= size {printf "    %.2fMB %s\n", $3/1048576, $4}' | \
    sort -rn)

  if [ -n "$large_files" ]; then
    echo "$large_files"
  else
    echo "    No files >= ${SIZE_MB}MB found"
  fi

  cd - > /dev/null || exit
  rm -rf "$clone_path"

  echo ""
done < "$REPOS_FILE"

echo "============================================================"
echo "Scan complete"
