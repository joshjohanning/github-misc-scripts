#!/bin/bash
# Get open pull requests grouped by involvement:
# - Created by me
# - Assigned to me
# - Awaiting my review (requested reviewer)
# - Other involvement (mentioned or commented)
#
# Usage: ./get-my-pull-requests.sh [<exclude-organizations>]
# Example: ./get-my-pull-requests.sh
# Example: ./get-my-pull-requests.sh joshjohanning-org
# Example: ./get-my-pull-requests.sh joshjohanning-org,another-org
# Requires GitHub CLI authentication with access to the repositories being searched.

set -euo pipefail

usage() {
  echo "Usage: $0 [<exclude-organizations>]" >&2
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

search_pull_requests() {
  local incomplete_results key number owner repository results retrieval_count search_metadata search_query title total_count
  search_query="$1"

  if ! search_metadata=$(gh api --method GET /search/issues \
      -f q="$search_query" \
      -F per_page=1 \
      --jq '[.total_count, .incomplete_results] | @tsv'); then
    fail "Pull request search failed. Check repository access and API rate limits with: gh api rate_limit"
  fi
  IFS=$'\t' read -r total_count incomplete_results <<< "$search_metadata"

  if [[ "$incomplete_results" == "true" ]]; then
    fail "GitHub Search timed out while counting pull requests. Run the report again."
  fi

  if [[ "$total_count" -gt 1000 ]]; then
    fail "Search matched $total_count pull requests, but GitHub Search only exposes 1,000 results. The report stopped before completion."
  fi

  if ! results=$(gh api --method GET --paginate /search/issues \
      -f q="$search_query" \
      -F per_page=100 \
      -f sort=created \
      -f order=desc \
      --jq '(["__SEARCH_STATUS__", (.incomplete_results | tostring), (.total_count | tostring)] | @tsv),
        (.items[] | [(.repository_url | sub("^.*/repos/"; "")), .number, .title] | @tsv)'); then
    fail "Pull request search failed. Check repository access and API rate limits with: gh api rate_limit"
  fi

  [[ -n "$results" ]] || return

  while IFS=$'\t' read -r repository incomplete_results retrieval_count; do
    if [[ "$repository" == "__SEARCH_STATUS__" ]]; then
      if [[ "$incomplete_results" == "true" ]]; then
        fail "GitHub Search timed out while retrieving pull requests. Run the report again."
      fi
      if [[ "$retrieval_count" -gt 1000 ]]; then
        fail "Search grew to $retrieval_count pull requests during retrieval, but GitHub Search only exposes 1,000 results. The report stopped before completion."
      fi
    fi
  done <<< "$results"

  while IFS=$'\t' read -r repository number title; do
    [[ "$repository" != "__SEARCH_STATUS__" ]] || continue

    key="$repository#$number"
    if [[ "$seen_pull_requests" == *$'\n'"$key"$'\n'* ]]; then
      continue
    fi
    seen_pull_requests+="$key"$'\n'

    owner="${repository%%/*}"
    if ! is_excluded_organization "$owner"; then
      printf '%s\t%s\t%s\n' "$number" "$title" "$repository"
    fi
  done <<< "$results"
}

is_excluded_organization() {
  local organization owner="$1"

  [[ -n "$exclude_orgs" ]] || return 1

  for organization in "${organizations[@]}"; do
    if [[ "$owner" == "$organization" ]]; then
      return 0
    fi
  done

  return 1
}

if [[ $# -gt 1 ]]; then
  echo "Error: Expected at most one argument, but received $#." >&2
  usage
  exit 1
fi
command -v gh >/dev/null 2>&1 ||
  fail "Required command not found: gh"
gh auth status >/dev/null 2>&1 ||
  fail "GitHub CLI is not authenticated. Run: gh auth login"

exclude_orgs="${1:-}"
user=$(gh api user --jq '.login')

organizations=()
if [ -n "$exclude_orgs" ]; then
  [[ "$exclude_orgs" != ,* && "$exclude_orgs" != *, && "$exclude_orgs" != *,,* ]] ||
    fail "Excluded organizations must be a comma-separated list without empty values."
  IFS=',' read -ra organizations <<< "$exclude_orgs"
  for organization in "${organizations[@]}"; do
    [[ "$organization" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] ||
      fail "Invalid organization name: $organization"
  done
fi

shopt -s nocasematch
seen_pull_requests=$'\n'

echo "Fetching open pull requests for @$user..." >&2
echo "" >&2

echo "## Created by me"
search_pull_requests "author:$user is:pr is:open"

echo "" >&2
echo "## Assigned to me"
search_pull_requests "assignee:$user -author:$user is:pr is:open"

echo "" >&2
echo "## Awaiting my review (requested reviewer)"
search_pull_requests "review-requested:$user -author:$user -assignee:$user is:pr is:open"

echo "" >&2
echo "## Other involvement"
search_pull_requests "involves:$user -author:$user -assignee:$user -review-requested:$user is:pr is:open"

echo "" >&2
echo "Done!" >&2
