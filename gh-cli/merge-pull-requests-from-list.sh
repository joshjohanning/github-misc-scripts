#!/bin/bash

# Merges a list of pull requests from a file containing PR URLs
#
# Usage:
#   ./merge-pull-requests-from-list.sh <pr_list_file> [merge_method] [commit_title] [commit_body] [--dry-run]
#
# Arguments:
#   pr_list_file   - File with PR URLs (one per line)
#   merge_method   - Optional: merge method (merge, squash, rebase) - defaults to squash
#   commit_title   - Optional: custom commit title (use {title} for original PR title, {number} for PR number)
#   commit_body    - Optional: custom commit body (use {body} for original PR body)
#   --dry-run      - Optional: preview what would be merged without actually merging
#
# Examples:
#   # Basic usage with a PR list file (uses squash merge)
#   ./merge-pull-requests-from-list.sh prs.txt
#
#   # Specify merge method
#   ./merge-pull-requests-from-list.sh prs.txt merge
#   ./merge-pull-requests-from-list.sh prs.txt rebase
#
#   # Custom commit title (squash/merge only)
#   ./merge-pull-requests-from-list.sh prs.txt squash "chore(deps): {title}"
#
#   # Custom commit title and body
#   ./merge-pull-requests-from-list.sh prs.txt squash "chore(deps): {title}" "Merged via automation"
#
#   # Dry run to preview merges
#   ./merge-pull-requests-from-list.sh prs.txt squash "" "" --dry-run
#
# Input file format (prs.txt):
#   https://github.com/joshjohanning/repo1/pull/25
#   https://github.com/joshjohanning/repo2/pull/37
#   https://github.com/joshjohanning/repo3/pull/43
#
# Notes:
#   - Ensure you have merge permissions on all repositories
#   - PRs must be in a mergeable state (approved, checks passed, no conflicts)
#   - The script will skip PRs that cannot be merged and continue with the rest
#   - Rebase merge method does not support custom commit messages
#
# TODO:
#   - Add --delete-branch flag to delete remote branch after merge
#   - Add --bypass flag to bypass branch protection requirements

merge_methods=("merge" "squash" "rebase")

# Check for --dry-run flag anywhere in arguments
dry_run=false
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    dry_run=true
    break
  fi
done

if [ $# -lt 1 ]; then
  echo "Usage: $0 <pr_list_file> [merge_method] [commit_title] [commit_body] [--dry-run]"
  echo ""
  echo "Arguments:"
  echo "  pr_list_file   - File with PR URLs (one per line)"
  echo "  merge_method   - Optional: merge, squash, or rebase (default: squash)"
  echo "  commit_title   - Optional: custom commit title (use {title} for PR title, {number} for PR number)"
  echo "  commit_body    - Optional: custom commit body (use {body} for PR body)"
  echo "  --dry-run      - Preview what would be merged without actually merging"
  exit 1
fi

pr_list_file=$1
merge_method=${2:-squash}
commit_title=${3:-}
commit_body=${4:-}

if [ "$dry_run" = true ]; then
  echo "🔍 DRY RUN MODE - No PRs will be merged"
  echo ""
fi

# Validate merge method
if [[ ! " ${merge_methods[*]} " =~ ${merge_method} ]]; then
  echo "Error: merge_method must be one of: ${merge_methods[*]}"
  exit 1
fi

# Check if file exists
if [ ! -f "$pr_list_file" ]; then
  echo "Error: File $pr_list_file does not exist"
  exit 1
fi

# Warn about custom messages with rebase
if [ "$merge_method" = "rebase" ] && { [ -n "$commit_title" ] || [ -n "$commit_body" ]; }; then
  echo "Warning: Rebase merge does not support custom commit messages, they will be ignored"
fi

success_count=0
fail_count=0
skipped_count=0

while IFS= read -r pr_url || [ -n "$pr_url" ]; do
  # Skip empty lines and comments
  if [ -z "$pr_url" ] || [[ "$pr_url" == \#* ]]; then
    continue
  fi

  # Trim whitespace
  pr_url=$(echo "$pr_url" | xargs)

  # Parse PR URL: https://github.com/owner/repo/pull/123
  if [[ "$pr_url" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
    pr_number="${BASH_REMATCH[3]}"
  else
    echo "⚠️  Skipping invalid PR URL: $pr_url"
    ((skipped_count++))
    continue
  fi

  echo "Processing: $owner/$repo#$pr_number"

  # Get PR details for template substitution
  pr_info=$(gh api "/repos/$owner/$repo/pulls/$pr_number" 2>/dev/null)

  if [ $? -ne 0 ]; then
    echo "❌ Failed to fetch PR info for $owner/$repo#$pr_number"
    ((fail_count++))
    continue
  fi

  pr_title=$(echo "$pr_info" | jq -r '.title')
  pr_body=$(echo "$pr_info" | jq -r '.body // ""')
  pr_state=$(echo "$pr_info" | jq -r '.state')
  pr_merged=$(echo "$pr_info" | jq -r '.merged')

  # Check if PR is already merged
  if [ "$pr_merged" = "true" ]; then
    echo "⏭️  Skipping $owner/$repo#$pr_number - already merged"
    ((skipped_count++))
    continue
  fi

  # Check if PR is closed
  if [ "$pr_state" = "closed" ]; then
    echo "⏭️  Skipping $owner/$repo#$pr_number - PR is closed"
    ((skipped_count++))
    continue
  fi

  # Build the merge command
  merge_args=("--$merge_method")

  # Always include PR number in commit subject (e.g., "commit message (#123)")
  if [ "$merge_method" != "rebase" ]; then
    if [ -n "$commit_title" ]; then
      final_title="${commit_title//\{title\}/$pr_title}"
      final_title="${final_title//\{number\}/$pr_number}"
    else
      final_title="$pr_title"
    fi
    merge_args+=("--subject" "$final_title (#$pr_number)")
  fi

  # Apply custom commit body with template substitution
  if [ -n "$commit_body" ] && [ "$merge_method" != "rebase" ]; then
    final_body="${commit_body//\{body\}/$pr_body}"
    final_body="${final_body//\{title\}/$pr_title}"
    final_body="${final_body//\{number\}/$pr_number}"
    merge_args+=("--body" "$final_body")
  fi

  # Attempt to merge
  if [ "$dry_run" = true ]; then
    echo "🔍 Would merge $owner/$repo#$pr_number with: gh pr merge $pr_number --repo $owner/$repo ${merge_args[*]}"
    ((success_count++))
  elif gh pr merge "$pr_number" --repo "$owner/$repo" "${merge_args[@]}"; then
    echo "✅ Successfully merged $owner/$repo#$pr_number"
    ((success_count++))
  else
    echo "❌ Failed to merge $owner/$repo#$pr_number"
    ((fail_count++))
  fi

  echo ""

done < "$pr_list_file"

echo "========================================"
echo "Summary:"
echo "  ✅ Merged:  $success_count"
echo "  ❌ Failed:  $fail_count"
echo "  ⏭️  Skipped: $skipped_count"
echo "========================================"

if [ "$dry_run" = true ]; then
  echo ""
  echo "🔍 This was a DRY RUN - no PRs were actually merged"
fi
