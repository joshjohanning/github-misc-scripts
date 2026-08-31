#!/usr/bin/env bash
# Get open pull requests grouped by involvement:
# - Created by me
# - Assigned to me
# - Awaiting my review (requested reviewer)
# - Involved (mentioned, assigned, authored, or commented)
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
  local search_query="$1"

  gh api --method GET --paginate /search/issues \
    -f q="$search_query" \
    -F per_page=100 \
    --jq '.items[] | [.number, .title, (.repository_url | sub("^.*/repos/"; ""))] | @tsv'
}

[[ $# -le 1 ]] || { usage; exit 1; }
command -v gh >/dev/null 2>&1 ||
  fail "Required command not found: gh"
gh auth status >/dev/null 2>&1 ||
  fail "GitHub CLI is not authenticated. Run: gh auth login"

exclude_orgs="${1:-}"
user=$(gh api user --jq '.login')

exclusion=""
if [ -n "$exclude_orgs" ]; then
  IFS=',' read -ra orgs <<< "$exclude_orgs"
  for org in "${orgs[@]}"; do
    [[ "$org" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] ||
      fail "Invalid organization name: $org"
    exclusion="$exclusion -org:$org"
  done
fi

echo "Fetching open pull requests for @$user..." >&2
echo "" >&2

echo "## Created by me"
search_pull_requests "author:$user is:pr is:open$exclusion"

echo "" >&2
echo "## Assigned to me"
search_pull_requests "assignee:$user is:pr is:open$exclusion"

echo "" >&2
echo "## Awaiting my review (requested reviewer)"
search_pull_requests "review-requested:$user is:pr is:open$exclusion"

echo "" >&2
echo "## Involved"
search_pull_requests "involves:$user is:pr is:open$exclusion"

echo "" >&2
echo "Done!" >&2
