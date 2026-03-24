#!/bin/bash

# Finds and merges pull requests matching a title pattern across multiple repositories
#
# Usage:
#   ./merge-pull-requests-by-title.sh <repo_list_file> <pr_title_pattern> [merge_method] [commit_title] [flags...]
#   ./merge-pull-requests-by-title.sh --owner <owner> <pr_title_pattern> [--topic <topic>]... [merge_method] [commit_title] [flags...]
#
# Required (one of):
#   repo_list_file        - File with repository URLs (one per line)
#   --owner <owner>       - Search repositories for this user or organization
#
# Required:
#   pr_title_pattern      - Title pattern to match (exact match or use * for wildcard)
#
# Optional:
#   merge_method          - Merge method: merge, squash, or rebase (default: squash)
#   commit_title          - Custom commit title for merged PRs (PR number is auto-appended; defaults to PR title)
#   --topic <topic>       - Filter --owner repositories by topic (can be specified multiple times)
#   --dry-run             - Preview what would be merged without actually merging
#   --bump-patch-version  - Clone each matching PR branch, run npm version patch, commit, and push (mutually exclusive with --dry-run; does not merge unless combined with --enable-auto-merge)
#   --enable-auto-merge   - Enable auto-merge on matching PRs (can combine with --bump-patch-version)
#   --no-prompt           - Merge without interactive confirmation (default is to prompt before each merge)
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
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps)*" --bump-patch-version
#
#   # Bump patch version and enable auto-merge (bump, wait for CI, then auto-merge)
#   ./merge-pull-requests-by-title.sh repos.txt "chore(deps)*" --bump-patch-version --enable-auto-merge
#
#   # Search by owner instead of file list
#   ./merge-pull-requests-by-title.sh --owner joshjohanning-org "chore(deps): bump undici*" --no-prompt
#
#   # Search by owner and topic
#   ./merge-pull-requests-by-title.sh --owner joshjohanning --topic node-action "chore(deps)*" --bump-patch-version
#
#   # Search by owner and multiple topics
#   ./merge-pull-requests-by-title.sh --owner joshjohanning --topic node-action --topic github-action "chore(deps)*" --dry-run
#
# Input file format (repos.txt):
#   https://github.com/joshjohanning/repo1
#   https://github.com/joshjohanning/repo2
#   https://github.com/joshjohanning/repo3
#
# Notes:
#   - PRs must be open and in a mergeable state
#   - Use * as a wildcard in the title pattern (e.g., "chore(deps)*" matches any title starting with "chore(deps)")
#   - If multiple PRs match in a repo, all will be processed
#   - --bump-patch-version clones each matching PR branch to a temp dir, bumps the npm patch version, commits, and pushes
#   - --bump-patch-version is mutually exclusive with --dry-run (does not merge unless combined with --enable-auto-merge)
#   - --bump-patch-version only works with same-repo PRs (fork-based PRs are skipped)
#   - --enable-auto-merge queues PRs to merge once all required checks pass (does not bypass protections)
#   - By default, merge mode prompts for confirmation before each PR merge; use --no-prompt to skip
#
# TODO:
#   - Add --delete-branch flag to delete remote branch after merge
#   - Add --bypass flag to bypass branch protection requirements

merge_methods=("merge" "squash" "rebase")

# Check for flags and valued options
dry_run=false
bump_patch_version=false
enable_auto_merge=false
no_prompt=false
owner=""
topics=()
valid_flags=("--dry-run" "--bump-patch-version" "--enable-auto-merge" "--no-prompt" "--owner" "--topic")
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  arg="${args[$i]}"
  if [ "$arg" = "--dry-run" ]; then
    dry_run=true
  elif [ "$arg" = "--bump-patch-version" ]; then
    bump_patch_version=true
  elif [ "$arg" = "--enable-auto-merge" ]; then
    enable_auto_merge=true
  elif [ "$arg" = "--no-prompt" ]; then
    no_prompt=true
  elif [ "$arg" = "--owner" ]; then
    ((i++))
    owner="${args[$i]}"
    if [ -z "$owner" ] || [[ "$owner" == --* ]]; then
      echo "Error: --owner requires a value"
      exit 1
    fi
  elif [ "$arg" = "--topic" ]; then
    ((i++))
    topic_val="${args[$i]}"
    if [ -z "$topic_val" ] || [[ "$topic_val" == --* ]]; then
      echo "Error: --topic requires a value"
      exit 1
    fi
    topics+=("$topic_val")
  elif [[ "$arg" == --* ]]; then
    echo "Error: Unknown flag '$arg'"
    echo "Valid flags: ${valid_flags[*]}"
    exit 1
  fi
  ((i++))
done

if [ $# -lt 2 ]; then
  echo "Usage: $0 <repo_list_file> <pr_title_pattern> [merge_method] [commit_title] [flags...]"
  echo "       $0 --owner <owner> <pr_title_pattern> [--topic <topic>]... [merge_method] [commit_title] [flags...]"
  echo ""
  echo "Required (one of):"
  echo "  repo_list_file        - File with repository URLs (one per line)"
  echo "  --owner <owner>       - Search repositories for this user or organization"
  echo ""
  echo "Required:"
  echo "  pr_title_pattern      - Title pattern to match (use * for wildcard)"
  echo ""
  echo "Optional:"
  echo "  merge_method          - merge, squash, or rebase (default: squash)"
  echo "  commit_title          - Custom commit title for merged PRs (defaults to PR title)"
  echo "  --topic <topic>       - Filter --owner repositories by topic (repeatable)"
  echo "  --dry-run             - Preview what would be merged (cannot combine with --bump-patch-version or --enable-auto-merge)"
  echo "  --bump-patch-version  - Bump npm patch version on each matching PR branch and push (cannot combine with --dry-run)"
  echo "  --enable-auto-merge   - Enable auto-merge on matching PRs (can combine with --bump-patch-version, cannot combine with --dry-run)"
  echo "  --no-prompt           - Merge without interactive confirmation"
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

# Parse positional args, skipping flags and their values
positional_args=()
i=0
while [ $i -lt ${#args[@]} ]; do
  arg="${args[$i]}"
  if [ "$arg" = "--owner" ] || [ "$arg" = "--topic" ]; then
    ((i++)) # skip the value too
  elif [[ "$arg" != --* ]]; then
    positional_args+=("$arg")
  fi
  ((i++))
done

# When --owner is used, positional args shift (no repo_list_file needed)
if [ -n "$owner" ]; then
  pr_title_pattern=${positional_args[0]}
  merge_method=${positional_args[1]:-squash}
  commit_title=${positional_args[2]:-}
else
  repo_list_file=${positional_args[0]}
  pr_title_pattern=${positional_args[1]}
  merge_method=${positional_args[2]:-squash}
  commit_title=${positional_args[3]:-}
fi

if [ -z "$pr_title_pattern" ]; then
  echo "Error: pr_title_pattern is required"
  echo "Usage: $0 <repo_list_file> <pr_title_pattern> [merge_method] [commit_title] [flags...]"
  echo "       $0 --owner <owner> <pr_title_pattern> [--topic <topic>]... [merge_method] [commit_title] [flags...]"
  exit 1
fi

if [ -z "$owner" ] && [ -z "$repo_list_file" ]; then
  echo "Error: Either repo_list_file or --owner is required"
  exit 1
fi

if [ ${#topics[@]} -gt 0 ] && [ -z "$owner" ]; then
  echo "Error: --topic requires --owner"
  exit 1
fi

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

# Check if file exists (when using file mode)
if [ -z "$owner" ] && [ ! -f "$repo_list_file" ]; then
  echo "Error: File $repo_list_file does not exist"
  exit 1
fi

# Build repo list from --owner/--topic or from file
if [ -n "$owner" ]; then
  echo "Fetching repositories for owner: $owner"
  if [ ${#topics[@]} -gt 0 ]; then
    echo "Filtering by topics: ${topics[*]}"
  fi
  echo ""

  # Fetch repos from org (or user), optionally filtered by topics
  # Try org endpoint first, fall back to user endpoint
  # Build jq filter: repos must have ALL specified topics
  if [ ${#topics[@]} -gt 0 ]; then
    # Validate topic names (alphanumeric and hyphens only)
    for t in "${topics[@]}"; do
      if ! [[ "$t" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        echo "Error: Invalid topic '$t' - topics must be lowercase alphanumeric with hyphens"
        exit 1
      fi
    done
    topic_conditions=""
    for t in "${topics[@]}"; do
      if [ -n "$topic_conditions" ]; then
        topic_conditions="$topic_conditions and "
      fi
      topic_conditions="${topic_conditions}(.topics | index(\"$t\"))"
    done
    jq_topic_filter="select(.archived == false) | select($topic_conditions) | .html_url"
  else
    jq_topic_filter="select(.archived == false) | .html_url"
  fi

  repo_urls=$(gh api --paginate "/orgs/$owner/repos?per_page=100" \
    --jq ".[] | $jq_topic_filter" 2>/dev/null)
  owner_exit=$?
  repo_fetch_exit=$owner_exit

  if [ $owner_exit -ne 0 ] || [ -z "$repo_urls" ]; then
    repo_urls=$(gh api --paginate "/users/$owner/repos?per_page=100" \
      --jq ".[] | $jq_topic_filter" 2>/dev/null)
    repo_fetch_exit=$?
  fi

  if [ $repo_fetch_exit -ne 0 ] || [ -z "$repo_urls" ]; then
    echo "Error: Failed to fetch repositories for '$owner'"
    if [ -n "$repo_urls" ]; then
      echo "  $repo_urls"
    fi
    exit 1
  fi

  repo_count=$(echo "$repo_urls" | wc -l | xargs)
  echo "Found $repo_count repositories"
  echo ""
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
    jq_pattern="${jq_pattern//\{/\\\{}"
    jq_pattern="${jq_pattern//\}/\\\}}"
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
  api_stderr=$(mktemp)
  matching_prs=$(gh api --paginate "/repos/$repo/pulls?state=open" \
    --jq ".[] | $jq_filter | \"\(.number)|\(.title)|\(.user.login)|\(.head.ref)|\(.head.repo.full_name)\"" 2>"$api_stderr")
  api_exit=$?

  if [ $api_exit -ne 0 ]; then
    api_error=$(cat "$api_stderr")
    rm -f "$api_stderr"
    echo "  ❌ API error for $repo: $api_error"
    ((fail_count++))
    echo ""
    continue
  fi
  rm -f "$api_stderr"

  if [ -z "$matching_prs" ]; then
    echo "  📭 No matching PRs found"
    ((not_found_count++))
    echo ""
    continue
  fi

  # Process each matching PR
  while IFS='|' read -r pr_number pr_title pr_author pr_branch pr_head_repo; do
    echo "  📋 Found PR #$pr_number: $pr_title (by $pr_author)"

    if [ "$bump_patch_version" = true ]; then
      # Skip fork-based PRs since we can't push to the head repo
      if [ "$pr_head_repo" != "$repo" ]; then
        echo "  ⚠️  Skipping $repo#$pr_number - fork-based PR ($pr_head_repo), cannot push to branch"
        ((skipped_count++))
        continue
      fi

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
              ((fail_count++))
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
          if ! [[ -t 1 ]] || ! [[ -r /dev/tty ]]; then
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

done < <(if [ -n "$owner" ]; then echo "$repo_urls"; else cat "$repo_list_file"; fi)

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
