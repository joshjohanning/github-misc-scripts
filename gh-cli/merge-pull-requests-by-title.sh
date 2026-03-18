#!/bin/bash

# Finds and merges pull requests matching a title pattern across multiple repositories
#
# Usage:
#   ./merge-pull-requests-by-title.sh <repo_list_file> <pr_title_pattern> [merge_method] [commit_title] [--dry-run] [--bump-patch-version] [--enable-auto-merge] [--no-prompt]
#
# Arguments:
#   repo_list_file        - File with repository URLs (one per line)
#   pr_title_pattern      - Title pattern to match (exact match or use * for wildcard)
#   merge_method          - Optional: merge method (merge, squash, rebase) - defaults to squash
#   commit_title          - Optional: custom commit title for all merged PRs (PR number is auto-appended)
#   --dry-run             - Optional: preview what would be merged without actually merging
#   --bump-patch-version  - Optional: clone each matching PR branch, run npm version patch, commit, and push (mutually exclusive with --dry-run and merge)
#   --enable-auto-merge   - Optional: enable auto-merge on matching PRs (can combine with --bump-patch-version)
#   --no-prompt           - Optional: merge without interactive confirmation (default is to prompt before each merge)
#
# Examples:
#   # Find and merge PRs with exact title match (will prompt for confirmation)
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps-dev): bump eslint-plugin-jest from 29.5.0 to 29.9.0 in the eslint group"
#
#   # With custom commit title, no confirmation prompt
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps-dev): bump eslint*" squash "chore(deps): update eslint dependencies" --no-prompt
#
#   # Dry run to preview (flags can appear anywhere, no need for "" placeholders)
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps)*" --dry-run
#
#   # Bump patch version on matching PR branches (run before merging so CI can pass)
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps)*" squash "" --bump-patch-version
#
#   # Bump patch version and enable auto-merge (bump, wait for CI, then auto-merge)
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps)*" squash "" --bump-patch-version --enable-auto-merge
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
#   - --bump-patch-version clones each matching PR branch to a temp dir, bumps the npm patch version, commits, and pushes
#   - --bump-patch-version is mutually exclusive with --dry-run
#   - --enable-auto-merge queues PRs to merge once all required checks pass (does not bypass protections)
#   - By default, merge mode prompts for confirmation before each PR merge; use --no-prompt to skip
#
# TODO:
#   - Add --delete-branch flag to delete remote branch after merge
#   - Add --bypass flag to bypass branch protection requirements

merge_methods=("merge" "squash" "rebase")

# Check for --dry-run, --bump-patch-version, and --no-prompt flags anywhere in arguments
dry_run=false
bump_patch_version=false
enable_auto_merge=false
no_prompt=false
valid_flags=("--dry-run" "--bump-patch-version" "--enable-auto-merge" "--no-prompt")
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    dry_run=true
  elif [ "$arg" = "--bump-patch-version" ]; then
    bump_patch_version=true
  elif [ "$arg" = "--enable-auto-merge" ]; then
    enable_auto_merge=true
  elif [ "$arg" = "--no-prompt" ]; then
    no_prompt=true
  elif [[ "$arg" == --* ]]; then
    echo "Error: Unknown flag '$arg'"
    echo "Valid flags: ${valid_flags[*]}"
    exit 1
  fi
done

if [ $# -lt 2 ]; then
  echo "Usage: $0 <repo_list_file> <pr_title_pattern> [merge_method] [commit_title] [--dry-run] [--bump-patch-version] [--enable-auto-merge] [--no-prompt]"
  echo ""
  echo "Arguments:"
  echo "  repo_list_file        - File with repository URLs (one per line)"
  echo "  pr_title_pattern      - Title pattern to match (use * for wildcard)"
  echo "  merge_method          - Optional: merge, squash, or rebase (default: squash)"
  echo "  commit_title          - Optional: custom commit title for merged PRs (PR number is auto-appended)"
  echo "  --dry-run             - Preview what would be merged without actually merging"
  echo "  --bump-patch-version  - Bump npm patch version on each matching PR branch and push (mutually exclusive with --dry-run)"
  echo "  --enable-auto-merge   - Enable auto-merge on matching PRs (can combine with --bump-patch-version)"
  echo "  --no-prompt           - Merge without interactive confirmation (default is to prompt before each merge)"
  exit 1
fi

if [ "$dry_run" = true ] && [ "$bump_patch_version" = true ]; then
  echo "Error: --dry-run and --bump-patch-version are mutually exclusive"
  exit 1
fi

if [ "$dry_run" = true ] && [ "$enable_auto_merge" = true ]; then
  echo "Error: --dry-run and --enable-auto-merge are mutually exclusive"
  exit 1
fi

# Parse positional args, skipping flags
positional_args=()
for arg in "$@"; do
  if [[ "$arg" != --* ]]; then
    positional_args+=("$arg")
  fi
done

repo_list_file=${positional_args[0]}
pr_title_pattern=${positional_args[1]}
merge_method=${positional_args[2]:-squash}
commit_title=${positional_args[3]:-}

if [ "$dry_run" = true ]; then
  echo "🔍 DRY RUN MODE - No PRs will be merged"
  echo ""
fi

if [ "$bump_patch_version" = true ]; then
  echo "🔼 BUMP PATCH VERSION MODE - Will bump npm patch version on matching PR branches"
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
    # Escape backslashes and double quotes for embedding in jq string literal
    jq_pattern_escaped="${jq_pattern//\\/\\\\}"
    jq_pattern_escaped="${jq_pattern_escaped//\"/\\\"}"
    jq_filter="select(.title | test(\"^${jq_pattern_escaped}$\"))"
  else
    # Exact match - use simple string equality
    # Escape backslashes and double quotes for embedding in jq string literal
    jq_pattern_escaped="${pr_title_pattern//\\/\\\\}"
    jq_pattern_escaped="${jq_pattern_escaped//\"/\\\"}"
    jq_filter="select(.title == \"${jq_pattern_escaped}\")"
  fi

  # Get open PRs and filter by title (paginate to get all PRs)
  matching_prs=$(gh api --paginate "/repos/$repo/pulls?state=open" \
    --jq ".[] | $jq_filter | \"\(.number)|\(.title)|\(.user.login)|\(.head.ref)\"" 2>/dev/null)

  if [ -z "$matching_prs" ]; then
    echo "  📭 No matching PRs found"
    ((not_found_count++))
    echo ""
    continue
  fi

  # Process each matching PR
  while IFS='|' read -r pr_number pr_title pr_author pr_branch; do
    echo "  📋 Found PR #$pr_number: $pr_title (by $pr_author)"

    if [ "$bump_patch_version" = true ]; then
      # Clone to temp dir, bump patch version, commit, and push
      tmp_dir=$(mktemp -d)
      clone_dir="$tmp_dir/$repo_name"
      echo "  🔀 Cloning $repo (branch: $pr_branch) to $clone_dir"
      if ! gh repo clone "$repo" "$clone_dir" -- --quiet --branch "$pr_branch" 2>&1; then
        echo "  ❌ Failed to clone $repo"
        ((fail_count++))
        rm -rf "$tmp_dir"
        continue
      fi
      new_version=$(cd "$clone_dir" && npm version patch --no-git-tag-version --ignore-scripts)
      if [ -z "$new_version" ]; then
        echo "  ❌ Failed to bump version in $repo#$pr_number (is there a package.json?)"
        ((fail_count++))
        rm -rf "$tmp_dir"
        continue
      fi
      # Strip leading 'v' if present (npm version returns e.g. "v1.2.3")
      new_version="${new_version#v}"
      echo "  🔼 Bumped version to $new_version"
      if (cd "$clone_dir" && git add package.json && { git add package-lock.json 2>/dev/null || true; } && git commit -m "chore: bump version to $new_version"); then
        if (cd "$clone_dir" && git push origin "$pr_branch"); then
          echo "  ✅ Successfully pushed version bump to $repo/$pr_branch"
          ((success_count++))
          # Enable auto-merge if requested
          if [ "$enable_auto_merge" = true ]; then
            auto_merge_args=("--auto" "--$merge_method")
            if [ "$merge_method" != "rebase" ]; then
              if [ -n "$commit_title" ]; then
                auto_merge_args+=("--subject" "$commit_title (#$pr_number)")
              else
                auto_merge_args+=("--subject" "$pr_title (#$pr_number)")
              fi
            fi
            if gh pr merge "$pr_number" --repo "$repo" "${auto_merge_args[@]}"; then
              echo "  🔄 Auto-merge enabled for $repo#$pr_number"
            else
              echo "  ⚠️  Failed to enable auto-merge for $repo#$pr_number"
            fi
          fi
        else
          echo "  ❌ Failed to push version bump to $repo/$pr_branch"
          ((fail_count++))
        fi
      else
        echo "  ❌ Failed to commit version bump in $repo#$pr_number"
        ((fail_count++))
      fi
      rm -rf "$tmp_dir"
    else
      # Build the merge command
      merge_args=("--$merge_method")

      # Always include PR number in commit subject (e.g., "commit message (#123)")
      if [ "$merge_method" != "rebase" ]; then
        if [ -n "$commit_title" ]; then
          merge_args+=("--subject" "$commit_title (#$pr_number)")
        else
          merge_args+=("--subject" "$pr_title (#$pr_number)")
        fi
      fi

      # Check if status checks have failed before attempting merge (skip for auto-merge since it waits for checks)
      if [ "$enable_auto_merge" = false ]; then
        failed_checks=$(gh pr checks "$pr_number" --repo "$repo" --json "name,state" --jq '[.[] | select(.state == "FAILURE")] | length' 2>/dev/null)
        if [ -n "$failed_checks" ] && [ "$failed_checks" -gt 0 ] 2>/dev/null; then
          echo "  ⚠️  Skipping $repo#$pr_number - $failed_checks status check(s) failed"
          ((skipped_count++))
          continue
        fi
      fi

      # Attempt to merge (or enable auto-merge)
      if [ "$enable_auto_merge" = true ]; then
        merge_args+=("--auto")
      fi
      if [ "$dry_run" = true ]; then
        echo "  🔍 Would merge $repo#$pr_number with: gh pr merge $pr_number --repo $repo ${merge_args[*]}"
        ((success_count++))
      else
        # Prompt for confirmation unless --no-prompt was passed
        if [ "$no_prompt" = false ]; then
          if ! [[ -r /dev/tty ]]; then
            echo "Error: No TTY available for interactive prompt - use --no-prompt"
            exit 1
          fi
          read -r -p "  ❓ Merge $repo#$pr_number? [y/N] " confirm < /dev/tty
          if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "  ⏭️  Skipped $repo#$pr_number"
            ((skipped_count++))
            continue
          fi
        fi
        if gh pr merge "$pr_number" --repo "$repo" "${merge_args[@]}"; then
          if [ "$enable_auto_merge" = true ]; then
            echo "  🔄 Auto-merge enabled for $repo#$pr_number"
          else
            echo "  ✅ Successfully merged $repo#$pr_number"
          fi
          ((success_count++))
        else
          echo "  ❌ Failed to merge $repo#$pr_number"
          ((fail_count++))
        fi
      fi
    fi
  done <<< "$matching_prs"

  echo ""

done < "$repo_list_file"

echo "========================================"
echo "Summary:"
if [ "$bump_patch_version" = true ]; then
  echo "  ✅ Bumped:    $success_count"
else
  echo "  ✅ Merged:    $success_count"
fi
echo "  ❌ Failed:    $fail_count"
echo "  ⏭️  Skipped:  $skipped_count"
echo "  📭 No match: $not_found_count"
echo "========================================"

if [ "$dry_run" = true ]; then
  echo ""
  echo "🔍 This was a DRY RUN - no PRs were actually merged"
fi

if [ "$bump_patch_version" = true ] && [ "$enable_auto_merge" = true ]; then
  echo ""
  echo "🔼 Version bumps pushed and auto-merge enabled - PRs will merge once CI passes"
elif [ "$bump_patch_version" = true ]; then
  echo ""
  echo "🔼 Version bumps pushed - wait for CI to pass before merging"
fi
