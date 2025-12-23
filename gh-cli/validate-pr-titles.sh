#!/bin/bash

# Validates that all PRs in a list have the same title
#
# Usage: ./validate-pr-titles.sh <pr_list_file>

if [ $# -lt 1 ]; then
  echo "Usage: $0 <pr_list_file>"
  exit 1
fi

pr_list_file=$1

if [ ! -f "$pr_list_file" ]; then
  echo "Error: File $pr_list_file does not exist"
  exit 1
fi

# Temporary file to store title|url pairs
temp_file=$(mktemp)
trap "rm -f $temp_file" EXIT

while IFS= read -r pr_url || [ -n "$pr_url" ]; do
  [ -z "$pr_url" ] || [[ "$pr_url" == \#* ]] && continue
  pr_url=$(echo "$pr_url" | xargs)

  if [[ "$pr_url" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
    pr_number="${BASH_REMATCH[3]}"
  else
    echo "⚠️  Invalid URL: $pr_url"
    continue
  fi

  title=$(gh pr view "$pr_url" --json title --jq '.title' 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "❌ Failed to fetch: $pr_url"
    continue
  fi

  echo "📋 $owner/$repo#$pr_number: $title"
  echo "$title|$pr_url" >> "$temp_file"
done < "$pr_list_file"

echo ""
echo "========================================"
echo "Title Summary:"

# Get unique titles with counts, sorted by count descending
title_counts=$(cut -d'|' -f1 "$temp_file" | sort | uniq -c | sort -rn)
unique_count=$(echo "$title_counts" | wc -l | xargs)
max_count=$(echo "$title_counts" | head -1 | awk '{print $1}')

echo "$title_counts" | while read -r count title; do
  echo "  (${count}x) $title"
  # Show URLs for non-majority titles
  if [ "$count" -lt "$max_count" ]; then
    grep "^${title}|" "$temp_file" | cut -d'|' -f2 | while read -r url; do
      echo "       └─ $url"
    done
  fi
done

echo "========================================"

if [ "$unique_count" -eq 1 ]; then
  echo "✅ All PRs have the same title"
else
  echo "⚠️  PRs have $unique_count different titles"
fi
