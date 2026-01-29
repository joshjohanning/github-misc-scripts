#!/bin/bash

# Compares devDependencies in package.json across multiple repositories
# to identify differences in dependencies and versions
#
# Usage:
#   ./compare-dev-dependencies-across-repositories.sh <file-with-repo-urls>
#
# Example:
#   ./compare-dev-dependencies-across-repositories.sh repos.txt
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
  # Remove trailing slashes and extract owner/repo
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
  # Skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  repo=$(extract_repo "$line")
  echo "$repo"
done < "$input_file" | sort -u > "$repos_file"

repo_count=$(wc -l < "$repos_file" | tr -d ' ')
echo "Found $repo_count unique repositories to check"
echo "=========================================="
echo ""

# Fetch package.json from each repository
while IFS= read -r repo; do
  echo "Fetching package.json from $repo..."

  safe_name=$(echo "$repo" | tr '/' '_')
  deps_file="$temp_dir/${safe_name}.json"

  # Try to get package.json from the default branch
  package_json=$(gh api "repos/$repo/contents/package.json" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null)

  if [ -z "$package_json" ]; then
    echo "  ⚠️  No package.json found or unable to fetch"
    echo "{}" > "$deps_file"
    continue
  fi

  dev_deps=$(echo "$package_json" | jq -r '.devDependencies // {}' 2>/dev/null)

  if [ "$dev_deps" == "null" ] || [ -z "$dev_deps" ]; then
    echo "  ⚠️  No devDependencies found"
    echo "{}" > "$deps_file"
    continue
  fi

  dep_count=$(echo "$dev_deps" | jq 'keys | length')
  echo "  ✅ Found $dep_count devDependencies"
  echo "$dev_deps" > "$deps_file"
done < "$repos_file"

echo ""
echo "=========================================="
echo "COMPARISON RESULTS"
echo "=========================================="
echo ""

# Collect all unique dependency names across all repos
all_deps_file="$temp_dir/all_deps.txt"
while IFS= read -r repo; do
  safe_name=$(echo "$repo" | tr '/' '_')
  jq -r 'keys[]' "$temp_dir/${safe_name}.json" 2>/dev/null
done < "$repos_file" | sort -u > "$all_deps_file"

# Create a summary table
echo "DEPENDENCY VERSION MATRIX"
echo "--------------------------"
printf "%-45s" "Dependency"
while IFS= read -r repo; do
  short_repo=$(basename "$repo")
  # Truncate long names
  if [ ${#short_repo} -gt 18 ]; then
    short_repo="${short_repo:0:15}..."
  fi
  printf "| %-18s" "$short_repo"
done < "$repos_file"
echo ""

printf "%-45s" "$(printf '%.0s-' {1..45})"
while IFS= read -r repo; do
  printf "| %-18s" "$(printf '%.0s-' {1..18})"
done < "$repos_file"
echo ""

# Track mismatches
mismatch_file="$temp_dir/mismatches.txt"
missing_file="$temp_dir/missing.txt"
> "$mismatch_file"
> "$missing_file"

while IFS= read -r dep; do
  [ -z "$dep" ] && continue

  # Truncate long dep names for display
  display_dep="$dep"
  if [ ${#display_dep} -gt 43 ]; then
    display_dep="${display_dep:0:40}..."
  fi
  printf "%-45s" "$display_dep"

  versions=""
  present_count=0
  while IFS= read -r repo; do
    safe_name=$(echo "$repo" | tr '/' '_')
    version=$(jq -r --arg dep "$dep" '.[$dep] // "-"' "$temp_dir/${safe_name}.json" 2>/dev/null)

    # Truncate long versions for display
    display_version="$version"
    if [ ${#display_version} -gt 16 ]; then
      display_version="${display_version:0:13}..."
    fi
    printf "| %-18s" "$display_version"

    if [ "$version" != "-" ]; then
      versions="$versions$version"$'\n'
      present_count=$((present_count + 1))
    fi
  done < "$repos_file"
  echo ""

  # Check for version mismatches
  unique_count=$(echo "$versions" | grep -v '^$' | sort -u | wc -l | tr -d ' ')
  if [ "$unique_count" -gt 1 ]; then
    echo "$dep" >> "$mismatch_file"
  fi

  # Check if missing in some repos
  if [ "$present_count" -gt 0 ] && [ "$present_count" -lt "$repo_count" ]; then
    echo "$dep" >> "$missing_file"
  fi
done < "$all_deps_file"

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="

# Show which dependencies have version mismatches
echo ""
echo "Dependencies with version differences:"
echo "---------------------------------------"

mismatch_count=$(wc -l < "$mismatch_file" | tr -d ' ')

if [ "$mismatch_count" -eq 0 ]; then
  echo "✅ All repositories have matching devDependency versions!"
else
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    echo ""
    echo "📦 $dep:"
    while IFS= read -r repo; do
      safe_name=$(echo "$repo" | tr '/' '_')
      version=$(jq -r --arg dep "$dep" '.[$dep] // ""' "$temp_dir/${safe_name}.json" 2>/dev/null)
      if [ -n "$version" ]; then
        short_repo=$(basename "$repo")
        echo "   $short_repo: $version"
      fi
    done < "$repos_file"
  done < "$mismatch_file"

  echo ""
  echo "⚠️  Found $mismatch_count dependencies with version mismatches"
fi

# Show dependencies that are missing in some repos
echo ""
echo "Dependencies not present in all repositories:"
echo "----------------------------------------------"

missing_count=$(wc -l < "$missing_file" | tr -d ' ')

if [ "$missing_count" -eq 0 ]; then
  echo "✅ All dependencies are present in all repositories (or completely absent)"
else
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue

    present_repos=""
    missing_repos=""

    while IFS= read -r repo; do
      safe_name=$(echo "$repo" | tr '/' '_')
      version=$(jq -r --arg dep "$dep" '.[$dep] // ""' "$temp_dir/${safe_name}.json" 2>/dev/null)
      short_repo=$(basename "$repo")
      if [ -n "$version" ]; then
        present_repos="$present_repos $short_repo"
      else
        missing_repos="$missing_repos $short_repo"
      fi
    done < "$repos_file"

    echo ""
    echo "📦 $dep:"
    echo "   Present in:$present_repos"
    echo "   Missing in:$missing_repos"
  done < "$missing_file"

  echo ""
  echo "⚠️  Found $missing_count dependencies not present in all repositories"
fi

echo ""
echo "Done!"
