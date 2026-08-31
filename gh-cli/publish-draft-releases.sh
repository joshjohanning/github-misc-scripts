#!/bin/bash

# Publishes draft releases created for PRs recorded by merge-pull-requests-by-title.sh
#
# Usage:
#   ./publish-draft-releases.sh [manifest_file] [--no-prompt]
#
# Examples:
#   ./publish-draft-releases.sh
#   ./publish-draft-releases.sh .release-manifests/previous.json --no-prompt
#
# Requirements:
#   - gh authenticated with Contents: write permission for each repository
#   - jq installed
#
# Safety:
#   - A draft must be created after the recorded PR merge
#   - The draft's target commit must contain the recorded merge commit
#   - Exactly one unpublished draft must match each manifest entry

print_help() {
  echo "Publish draft releases associated with a merge manifest"
  echo ""
  echo "Usage: $0 [manifest_file] [--no-prompt]"
  echo ""
  echo "Defaults to .release-manifests/latest.json"
}

no_prompt=false
manifest_file=".release-manifests/latest.json"
manifest_provided=false

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      print_help
      exit 0
      ;;
    --no-prompt)
      no_prompt=true
      ;;
    --*)
      echo "Error: Unknown flag '$arg'"
      exit 1
      ;;
    *)
      if [ "$manifest_provided" = true ]; then
        echo "Error: Only one manifest file may be provided"
        exit 1
      fi
      manifest_file="$arg"
      manifest_provided=true
      ;;
  esac
done

if [ ! -f "$manifest_file" ]; then
  echo "Error: Manifest file does not exist: $manifest_file"
  exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
  echo "Error: gh is required but not installed"
  exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "Error: jq is required but not installed"
  exit 1
fi

if ! jq -e '.schemaVersion == 1 and (.pullRequests | type == "array")' "$manifest_file" > /dev/null 2>&1; then
  echo "Error: Invalid or unsupported release manifest: $manifest_file"
  exit 1
fi

if [ "$no_prompt" = false ] && { ! [[ -t 1 ]] || ! [[ -r /dev/tty ]]; }; then
  echo "Error: No TTY available for interactive prompt - use --no-prompt"
  exit 1
fi

published_count=0
skipped_count=0
failed_count=0

while IFS=$'\t' read -r repo pr_number pr_url merged_at merge_sha; do
  echo "Checking $pr_url"

  repo_info=$(gh api "/repos/$repo" --jq '[.default_branch, .html_url] | @tsv' 2>/dev/null)
  if [ -z "$repo_info" ]; then
    echo "  ❌ Could not read repository metadata"
    ((failed_count++))
    continue
  fi
  IFS=$'\t' read -r default_branch repo_url <<< "$repo_info"

  matching_drafts=""
  while IFS=$'\t' read -r release_id tag_name target created_at release_url; do
    [ -z "$release_id" ] && continue
    target="${target:-$default_branch}"
    target_sha=$(gh api "/repos/$repo/commits/$target" --jq '.sha' 2>/dev/null)
    if [ -z "$target_sha" ]; then
      continue
    fi

    comparison=$(gh api "/repos/$repo/compare/$merge_sha...$target_sha" --jq '.status' 2>/dev/null)
    if [ "$comparison" = "identical" ] || [ "$comparison" = "ahead" ]; then
      if [ -n "$matching_drafts" ]; then
        matching_drafts+=$'\n'
      fi
      matching_drafts+="$release_id"$'\t'"$tag_name"$'\t'"$created_at"$'\t'"$release_url"
    fi
  done < <(gh api --paginate "/repos/$repo/releases?per_page=100" \
    --jq ".[] | select(.draft == true and .created_at >= \"$merged_at\") | [.id, .tag_name, (.target_commitish // \"\"), .created_at, .html_url] | @tsv" 2>/dev/null)

  match_count=$(printf '%s\n' "$matching_drafts" | awk 'NF { count++ } END { print count+0 }')
  if [ "$match_count" -eq 0 ]; then
    echo "  ⏭️  No matching draft release found"
    ((skipped_count++))
    continue
  fi
  if [ "$match_count" -gt 1 ]; then
    echo "  ❌ Found $match_count matching drafts; refusing to guess"
    printf '%s\n' "$matching_drafts" | while IFS=$'\t' read -r _ tag _ url; do
      echo "     $tag - $url"
    done
    ((failed_count++))
    continue
  fi

  IFS=$'\t' read -r release_id tag_name created_at release_url <<< "$matching_drafts"
  echo "  📦 Matching draft: $tag_name ($created_at) - $release_url"

  if [ "$no_prompt" = false ]; then
    read -r -p "  ❓ Publish this draft release? [y/N] " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "  ⏭️  Skipped $release_url"
      ((skipped_count++))
      continue
    fi
  fi

  if gh api --method PATCH "/repos/$repo/releases/$release_id" -F draft=false > /dev/null; then
    echo "  ✅ Published $repo_url/releases/tag/$tag_name"
    ((published_count++))
  else
    echo "  ❌ Failed to publish $release_url"
    ((failed_count++))
  fi
done < <(jq -r '.pullRequests[] | [.repository, .pullRequestNumber, .pullRequestUrl, .mergedAt, .mergeCommitSha] | @tsv' "$manifest_file")

echo "========================================"
echo "Summary:"
echo "  ✅ Published: $published_count"
echo "  ❌ Failed:    $failed_count"
echo "  ⏭️  Skipped:   $skipped_count"
echo "========================================"

if [ "$failed_count" -gt 0 ]; then
  exit 1
fi
