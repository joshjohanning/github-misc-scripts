#!/bin/bash

# Finds and merges pull requests matching a title pattern across multiple repositories
#
# Usage:
#   ./merge-pull-requests-by-title.sh <repo_list_file> <pr_title_pattern> [merge_method] [commit_title] [--dry-run]
#
# Arguments:
#   repo_list_file    - File with repository URLs (one per line)
#   pr_title_pattern  - Title pattern to match (exact match or use * for wildcard)
#   merge_method      - Optional: merge method (merge, squash, rebase) - defaults to squash
#   commit_title      - Optional: custom commit title for all merged PRs
#   --dry-run         - Optional: preview what would be merged without actually merging
#
# Examples:
#   # Find and merge PRs with exact title match
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps-dev): bump eslint-plugin-jest from 29.5.0 to 29.9.0 in the eslint group"
#
#   # With custom commit title
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps-dev): bump eslint*" squash "chore(deps): update eslint dependencies"
#
#   # Dry run to preview
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps)*" squash "" --dry-run
#
# Input file format (repos.txt):
#   https://github.com/joshjohanning/repo1
#   https://github.com/joshjohanning/repo2
#   https://github.com/joshjohanning/repo3
#
# Notes:
#   - PRs must be open and in a mergeable state
#   - Use * as a wildcard in the title pattern (e.g., "chore(deps)*" matches any title starting with "chore(deps)")
#   - If multiple PRs match in a repo, all will be listed but only the first will be merged (use --dry-run to preview)
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

if [ $# -lt 2 ]; then
  echo "Usage: $0 <repo_list_file> <pr_title_pattern> [merge_method] [commit_title] [--dry-run]"
  echo ""
  echo "Arguments:"
  echo "  repo_list_file    - File with repository URLs (one per line)"
  echo "  pr_title_pattern  - Title pattern to match (use * for wildcard)"
  echo "  merge_method      - Optional: merge, squash, or rebase (default: squash)"
  echo "  commit_title      - Optional: custom commit title for merged PRs"
  echo "  --dry-run         - Preview what would be merged without actually merging"
  exit 1
fi

repo_list_file=$1
pr_title_pattern=$2
merge_method=${3:-squash}
commit_title=${4:-}

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
if [ ! -f "$repo_list_file" ]; then
  echo "Error: File $repo_list_file does not exist"
  exit 1
fi

echo "Searching for PRs matching: \"$pr_title_pattern\""
echo ""

success_count=0
fail_count=0
skipped_count=0
not_found_count=0

while IFS= read -r repo_url || [ -n "$repo_url" ]; do
  # Skip empty lines and comments
  if [ -z "$repo_url" ] || [[ "$repo_url" == \#* ]]; then
    continue
  fi

  # Trim whitespace
  repo_url=$(echo "$repo_url" | xargs)

  # Parse repo URL: https://github.com/owner/repo
  if [[ "$repo_url" =~ ^https://github\.com/([^/]+)/([^/]+)/?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo_name="${BASH_REMATCH[2]}"
    repo="$owner/$repo_name"
  else
    echo "⚠️  Skipping invalid repository URL: $repo_url"
    ((skipped_count++))
    continue
  fi

  echo "Searching: $repo"

  # Search for open PRs matching the title pattern
  # Use simple string equality for exact match, regex only if wildcard * is used
  if [[ "$pr_title_pattern" == *"*"* ]]; then
    # Has wildcard - convert to regex (escape special chars, then convert * to .*)
    jq_pattern="$pr_title_pattern"
    jq_pattern="${jq_pattern//\\/\\\\}"
    jq_pattern="${jq_pattern//./\\.}"
    jq_pattern="${jq_pattern//[/\\[}"
    jq_pattern="${jq_pattern//]/\\]}"
    jq_pattern="${jq_pattern//(/\\(}"
    jq_pattern="${jq_pattern//)/\\)}"
    jq_pattern="${jq_pattern//+/\\+}"
    jq_pattern="${jq_pattern//\?/\\?}"
    jq_pattern="${jq_pattern//^/\\^}"
    jq_pattern="${jq_pattern//$/\\$}"
    jq_pattern="${jq_pattern//|/\\|}"
    jq_pattern="${jq_pattern//\*/.*}"
    jq_filter="select(.title | test(\"^\" + \$pattern + \"$\"))"
  else
    # Exact match - use simple string equality
    jq_filter="select(.title == \$pattern)"
    jq_pattern="$pr_title_pattern"
  fi

  # Get open PRs and filter by title
  matching_prs=$(gh pr list --repo "$repo" --state open --json number,title,author --limit 100 2>/dev/null | \
    jq -r --arg pattern "$jq_pattern" ".[] | $jq_filter | \"\(.number)|\(.title)|\(.author.login)\"")

  if [ -z "$matching_prs" ]; then
    echo "  📭 No matching PRs found"
    ((not_found_count++))
    echo ""
    continue
  fi

  # Process each matching PR
  while IFS='|' read -r pr_number pr_title pr_author; do
    echo "  📋 Found PR #$pr_number: $pr_title (by $pr_author)"

    # Build the merge command
    merge_args=("--$merge_method")

    # Apply custom commit title if provided
    if [ -n "$commit_title" ] && [ "$merge_method" != "rebase" ]; then
      merge_args+=("--subject" "$commit_title")
    fi

    # Attempt to merge
    if [ "$dry_run" = true ]; then
      echo "  🔍 Would merge $repo#$pr_number with: gh pr merge $pr_number --repo $repo ${merge_args[*]}"
      ((success_count++))
    elif gh pr merge "$pr_number" --repo "$repo" "${merge_args[@]}"; then
      echo "  ✅ Successfully merged $repo#$pr_number"
      ((success_count++))
    else
      echo "  ❌ Failed to merge $repo#$pr_number"
      ((fail_count++))
    fi
  done <<< "$matching_prs"

  echo ""

done < "$repo_list_file"

echo "========================================"
echo "Summary:"
echo "  ✅ Merged:    $success_count"
echo "  ❌ Failed:    $fail_count"
echo "  ⏭️  Skipped:  $skipped_count"
echo "  📭 No match: $not_found_count"
echo "========================================"

if [ "$dry_run" = true ]; then
  echo ""
  echo "🔍 This was a DRY RUN - no PRs were actually merged"
fi
