#!/bin/bash

# Deletes intermediate draft releases created for PRs recorded by merge-pull-requests-by-title.sh
#
# Usage:
#   ./delete-draft-releases.sh [manifest_file] [--max-age-minutes <minutes>] [--no-prompt]
#
# Examples:
#   ./delete-draft-releases.sh
#   ./delete-draft-releases.sh --max-age-minutes 15 --no-prompt
#   ./delete-draft-releases.sh .release-manifests/previous.json --max-age-minutes 15
#
# Requirements:
#   - gh authenticated with Contents: write permission for each repository
#   - jq installed
#
# Safety:
#   - Only draft releases created after the recorded PR merge are considered
#   - The draft target must contain the recorded merge commit
#   - Only the exact tag named by the verified draft is deleted
#   - Exactly one draft must match each manifest entry

print_help() {
  echo "Delete intermediate draft releases associated with a merge manifest"
  echo ""
  echo "Usage: $0 [manifest_file] [--max-age-minutes <minutes>] [--no-prompt]"
  echo ""
  echo "Defaults to .release-manifests/latest.json"
}

no_prompt=false
max_age_minutes=""
manifest_file=".release-manifests/latest.json"
manifest_provided=false

args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  arg="${args[$i]}"
  case "$arg" in
    -h|--help)
      print_help
      exit 0
      ;;
    --no-prompt)
      no_prompt=true
      ;;
    --max-age-minutes)
      ((i++))
      max_age_minutes="${args[$i]}"
      if ! [[ "$max_age_minutes" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: --max-age-minutes requires a positive integer"
        exit 1
      fi
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
  ((i++))
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

deleted_count=0
skipped_count=0
failed_count=0

while IFS=$'\t' read -r repo pr_url merged_at merge_sha; do
  if [ "$deleted_count" -gt 0 ] || [ "$skipped_count" -gt 0 ] || [ "$failed_count" -gt 0 ]; then
    echo ""
  fi
  echo "Checking $pr_url"

  default_branch=$(gh api "/repos/$repo" --jq '.default_branch' 2>/dev/null)
  if [ -z "$default_branch" ]; then
    echo "  ❌ Could not read repository metadata"
    ((failed_count++))
    continue
  fi

  matching_drafts=""
  release_query_error=$(mktemp)
  releases=$(gh api --paginate "/repos/$repo/releases?per_page=100" \
    --jq ".[] | select(.draft == true and .created_at >= \"$merged_at\") | [.id, .tag_name, (.target_commitish // \"\"), .created_at, .html_url] | @tsv" 2>"$release_query_error")
  release_query_status=$?
  if [ $release_query_status -ne 0 ]; then
    echo "  ❌ Failed to list releases: $(cat "$release_query_error")"
    rm -f "$release_query_error"
    ((failed_count++))
    continue
  fi
  rm -f "$release_query_error"

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
  done <<< "$releases"

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
  if [ -n "$max_age_minutes" ]; then
    created_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" "+%s" 2>/dev/null)
    if [ -z "$created_epoch" ]; then
      created_epoch=$(date -u -d "$created_at" "+%s" 2>/dev/null)
    fi
    if [ -z "$created_epoch" ]; then
      echo "  ❌ Could not parse draft creation time: $created_at"
      ((failed_count++))
      continue
    fi

    current_epoch=$(date -u "+%s")
    age_seconds=$((current_epoch - created_epoch))
    max_age_seconds=$((max_age_minutes * 60))
    if [ "$age_seconds" -gt "$max_age_seconds" ]; then
      echo "  ⏭️  Draft is older than $max_age_minutes minutes; skipping $release_url"
      ((skipped_count++))
      continue
    fi
  fi

  current_release=$(gh api "/repos/$repo/releases/$release_id" --jq '[.draft, .tag_name] | @tsv' 2>/dev/null)
  if [ "$current_release" != $'true\t'"$tag_name" ]; then
    echo "  ❌ Release changed during verification; refusing to delete $release_url"
    ((failed_count++))
    continue
  fi

  encoded_tag=$(jq -rn --arg value "$tag_name" '$value | @uri')
  tag_ref=$(gh api "/repos/$repo/git/ref/tags/$encoded_tag" --jq '.ref' 2>/dev/null)
  if [ "$tag_ref" != "refs/tags/$tag_name" ]; then
    echo "  ❌ Exact tag $tag_name was not found; refusing partial cleanup"
    ((failed_count++))
    continue
  fi

  echo "  📦 Matching draft: $tag_name ($created_at) - $release_url"
  if [ "$no_prompt" = false ]; then
    read -r -p "  ❓ Delete this intermediate draft release and tag $tag_name? [y/N] " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "  ⏭️  Skipped $release_url"
      ((skipped_count++))
      continue
    fi
  fi

  if gh api --method DELETE "/repos/$repo/releases/$release_id" > /dev/null; then
    if gh api --method DELETE "/repos/$repo/git/refs/tags/$encoded_tag" > /dev/null; then
      echo "  ✅ Deleted intermediate draft $release_url and tag $tag_name"
      ((deleted_count++))
    else
      echo "  ❌ Deleted the draft but failed to delete tag $tag_name"
      ((failed_count++))
    fi
  else
    echo "  ❌ Failed to delete $release_url"
    ((failed_count++))
  fi
done < <(jq -r '.pullRequests[] | [.repository, .pullRequestUrl, .mergedAt, .mergeCommitSha] | @tsv' "$manifest_file")

echo "========================================"
echo "Summary:"
printf "  ✅ %-10s %d\n" "Deleted:" "$deleted_count"
printf "  ❌ %-10s %d\n" "Failed:" "$failed_count"
printf "  ⏭️  %-10s %d\n" "Skipped:" "$skipped_count"
echo "========================================"

if [ "$failed_count" -gt 0 ]; then
  exit 1
fi
