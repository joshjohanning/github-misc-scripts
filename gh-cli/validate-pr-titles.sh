#!/bin/zsh

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

typeset -A titles
typeset -A title_urls
first_title=""

while IFS= read -r pr_url || [ -n "$pr_url" ]; do
  [ -z "$pr_url" ] || [[ "$pr_url" == \#* ]] && continue
  pr_url=$(echo "$pr_url" | xargs)

  if [[ "$pr_url" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    owner="${match[1]}"
    repo="${match[2]}"
    pr_number="${match[3]}"
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

  if [ -z "$first_title" ]; then
    first_title="$title"
  fi

  titles[$title]=$((${titles[$title]:-0} + 1))
  # Append URL to the list for this title
  if [ -z "${title_urls[$title]}" ]; then
    title_urls[$title]="$pr_url"
  else
    title_urls[$title]="${title_urls[$title]}|$pr_url"
  fi
done < "$pr_list_file"

echo ""
echo "========================================"
echo "Title Summary:"

# Find the majority count
max_count=0
for title in "${(@k)titles}"; do
  if [ ${titles[$title]} -gt $max_count ]; then
    max_count=${titles[$title]}
  fi
done

for title in "${(@k)titles}"; do
  echo "  (${titles[$title]}x) $title"
  # Show URLs for non-majority titles
  if [ ${titles[$title]} -lt $max_count ]; then
    echo "${title_urls[$title]}" | tr '|' '\n' | while read -r url; do
      echo "       └─ $url"
    done
  fi
done
echo "========================================"

if [ ${#titles[@]} -eq 1 ]; then
  echo "✅ All PRs have the same title"
else
  echo "⚠️  PRs have ${#titles[@]} different titles"
fi
