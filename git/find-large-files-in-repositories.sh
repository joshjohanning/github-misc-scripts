#!/bin/bash

# Finds files over a specified size (default: 100MB) across multiple git repositories
# Reads repository URLs from a text file (one URL per line)
#
# Prerequisites:
# - git must be installed
# - Standard Unix tools: awk, sort, mktemp, basename
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

# Validate SIZE_MB is a positive integer
if ! [[ "$SIZE_MB" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: size-in-mb must be a positive integer (received: '$SIZE_MB')"
  exit 1
fi

SIZE_BYTES=$((SIZE_MB * 1048576))

if [ ! -f "$REPOS_FILE" ]; then
  echo "Error: File '$REPOS_FILE' not found"
  exit 1
fi

# Create a temporary directory for clones
TEMP_DIR=$(mktemp -d)
trap 'if [ -n "${TEMP_DIR:-}" ]; then rm -rf -- "$TEMP_DIR"; fi' EXIT

echo "Finding files >= ${SIZE_MB}MB in repositories listed in $REPOS_FILE"
echo "============================================================"
echo ""

while IFS= read -r repo_url || [ -n "$repo_url" ]; do
  # Skip empty lines and comments
  [[ -z "$repo_url" || "$repo_url" =~ ^# ]] && continue

  repo_name=$(basename "$repo_url" .git)
  echo "=== Checking: $repo_name ==="
  echo "    URL: $repo_url"

  # Use hash of URL to avoid collisions when repos have the same name
  repo_hash=$(printf '%s' "$repo_url" | md5 -q 2>/dev/null || printf '%s' "$repo_url" | md5sum | awk '{print $1}')
  clone_path="$TEMP_DIR/${repo_name}-${repo_hash}.git"

  if ! clone_output=$(git clone --bare "$repo_url" "$clone_path" 2>&1); then
    echo "    Error: Failed to clone repository"
    echo "    git clone output:"
    echo "$clone_output" | sed 's/^/      /'
    rm -rf "$clone_path"
    echo ""
    continue
  fi

  cd "$clone_path" || continue

  # Find files over the specified size
  # Use tab delimiter to preserve filenames with spaces
  git rev-list --objects --all 2>/dev/null | \
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize)	%(rest)' 2>/dev/null | \
    awk -v size="$SIZE_BYTES" -F '\t' '{
      split($1, meta, " ")
      if (meta[1] == "blob" && meta[3] >= size) {
        printf "    %.2fMB %s\n", meta[3]/1048576, $2
      }
    }' | \
    sort -rn | {
      found=0
      while IFS= read -r line; do
        found=1
        echo "$line"
      done
      if [ "$found" -eq 0 ]; then
        echo "    No files >= ${SIZE_MB}MB found"
      fi
    }

  cd - > /dev/null || exit
  rm -rf "$clone_path"

  echo ""
done < "$REPOS_FILE"

echo "============================================================"
echo "Scan complete"
