#!/bin/bash

# Compares package.json scripts across multiple repositories
# to identify differences in script names and values
#
# Usage:
#   ./compare-package-scripts-across-repositories.sh <file-with-repo-urls>
#
# Example:
#   ./compare-package-scripts-across-repositories.sh repos.txt
#
# Where repos.txt contains one repository URL or PR URL per line:
#   https://github.com/owner/repo
#   https://github.com/owner/repo/pull/123
#
# Prerequisites:
#   - gh cli installed and authenticated
#   - jq installed

if [ -z "$1" ]; then
  echo "Usage: $0 <file-with-repo-urls>"
  echo "File should contain repository URLs or PR URLs, one per line"
  exit 1
fi

input_file="$1"

if [ ! -f "$input_file" ]; then
  echo "Error: File '$input_file' not found"
  exit 1
fi

# Check for required tools
if ! command -v gh &> /dev/null; then
  echo "Error: gh cli is required but not installed"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed"
  exit 1
fi

# Extract owner/repo from various URL formats
extract_repo() {
  local url="$1"
  echo "$url" | sed -E 's|https://github.com/||' | sed -E 's|/pull/[0-9]+.*||' | sed -E 's|/$||'
}

# Create temp directory for storing data
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Collect all unique repositories
repos_file="$temp_dir/repos.txt"
while IFS= read -r line || [ -n "$line" ]; do
  # Trim leading and trailing whitespace
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  repo=$(extract_repo "$line")
  echo "$repo"
done < "$input_file" | sort -u > "$repos_file"

repo_count=$(wc -l < "$repos_file" | tr -d ' ')
echo "Found $repo_count unique repositories to check"
echo "=========================================="
echo ""

# Fetch package.json scripts from each repository
while IFS= read -r repo; do
  echo "Fetching package.json from $repo..."

  safe_name=$(echo "$repo" | tr '/' '_')
  scripts_file="$temp_dir/${safe_name}.json"

  package_json=$(gh api "repos/$repo/contents/package.json" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null)

  if [ -z "$package_json" ]; then
    echo "  ⚠️  No package.json found or unable to fetch"
    echo "{}" > "$scripts_file"
    continue
  fi

  scripts=$(echo "$package_json" | jq -r '.scripts // {}' 2>/dev/null)

  if [ "$scripts" == "null" ] || [ -z "$scripts" ]; then
    echo "  ⚠️  No scripts found"
    echo "{}" > "$scripts_file"
    continue
  fi

  script_count=$(echo "$scripts" | jq 'keys | length')
  echo "  ✅ Found $script_count scripts"
  echo "$scripts" > "$scripts_file"
done < "$repos_file"

echo ""
echo "=========================================="
echo "SCRIPTS BY REPOSITORY"
echo "=========================================="

while IFS= read -r repo; do
  safe_name=$(echo "$repo" | tr '/' '_')
  short_repo=$(basename "$repo")
  echo ""
  echo "📦 $short_repo:"
  jq -r 'to_entries | sort_by(.key)[] | "   \(.key): \(.value)"' "$temp_dir/${safe_name}.json" 2>/dev/null
done < "$repos_file"

echo ""
echo "=========================================="
echo "COMPARISON RESULTS"
echo "=========================================="
echo ""

# Collect all unique script names across all repos
all_scripts_file="$temp_dir/all_scripts.txt"
while IFS= read -r repo; do
  safe_name=$(echo "$repo" | tr '/' '_')
  jq -r 'keys[]' "$temp_dir/${safe_name}.json" 2>/dev/null
done < "$repos_file" | sort -u > "$all_scripts_file"

# Track mismatches and missing
mismatch_file="$temp_dir/mismatches.txt"
missing_file="$temp_dir/missing.txt"
> "$mismatch_file"
> "$missing_file"

while IFS= read -r script; do
  [ -z "$script" ] && continue

  values=""
  present_count=0
  while IFS= read -r repo; do
    safe_name=$(echo "$repo" | tr '/' '_')
    value=$(jq -r --arg script "$script" '.[$script] // ""' "$temp_dir/${safe_name}.json" 2>/dev/null)

    if [ -n "$value" ]; then
      values="$values$value"$'\n'
      present_count=$((present_count + 1))
    fi
  done < "$repos_file"

  # Check for value mismatches
  unique_count=$(echo "$values" | grep -v '^$' | sort -u | wc -l | tr -d ' ')
  if [ "$unique_count" -gt 1 ]; then
    echo "$script" >> "$mismatch_file"
  fi

  # Check if missing in some repos
  if [ "$present_count" -gt 0 ] && [ "$present_count" -lt "$repo_count" ]; then
    echo "$script" >> "$missing_file"
  fi
done < "$all_scripts_file"

# Show scripts with value differences
echo "Scripts with different values:"
echo "------------------------------"

mismatch_count=$(wc -l < "$mismatch_file" | tr -d ' ')

if [ "$mismatch_count" -eq 0 ]; then
  echo "✅ All repositories have matching script values!"
else
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    echo ""
    echo "📜 $script:"
    while IFS= read -r repo; do
      safe_name=$(echo "$repo" | tr '/' '_')
      value=$(jq -r --arg script "$script" '.[$script] // ""' "$temp_dir/${safe_name}.json" 2>/dev/null)
      if [ -n "$value" ]; then
        short_repo=$(basename "$repo")
        echo "   $short_repo: $value"
      fi
    done < "$repos_file"
  done < "$mismatch_file"

  echo ""
  echo "⚠️  Found $mismatch_count scripts with different values"
fi

# Show scripts that are missing in some repos
echo ""
echo "Scripts not present in all repositories:"
echo "-----------------------------------------"

missing_count=$(wc -l < "$missing_file" | tr -d ' ')

if [ "$missing_count" -eq 0 ]; then
  echo "✅ All scripts are present in all repositories (or completely absent)"
else
  while IFS= read -r script; do
    [ -z "$script" ] && continue

    present_repos=""
    missing_repos=""

    while IFS= read -r repo; do
      safe_name=$(echo "$repo" | tr '/' '_')
      value=$(jq -r --arg script "$script" '.[$script] // ""' "$temp_dir/${safe_name}.json" 2>/dev/null)
      short_repo=$(basename "$repo")
      if [ -n "$value" ]; then
        present_repos="$present_repos $short_repo"
      else
        missing_repos="$missing_repos $short_repo"
      fi
    done < "$repos_file"

    echo ""
    echo "📜 $script:"
    echo "   Present in:$present_repos"
    echo "   Missing in:$missing_repos"
  done < "$missing_file"

  echo ""
  echo "⚠️  Found $missing_count scripts not present in all repositories"
fi

echo ""
echo "Done!"
