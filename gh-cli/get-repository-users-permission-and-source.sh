#!/bin/bash

# Returns the permission for everyone who can access a repository and how they
# access it (direct, team, organization)
#
# Uses the REST API to get accurate team role names (maintain, triage) since the
# GraphQL permissionSources API only returns READ, WRITE, and ADMIN. A heuristic
# is also applied to direct sources to correct MAINTAIN/TRIAGE labels.
#
# gh cli's token needs to be able to admin the organization - run this first if needed:
#   gh auth refresh -h github.com -s admin:org
#
# Usage:
#   ./get-repository-users-permission-and-source.sh <org> <repo> [affiliation] [hostname]
#
# affiliation can be: OUTSIDE, DIRECT, ALL (default: ALL)
# hostname: GitHub hostname (default: github.com), e.g. github.example.com

# Example output:
#
# USER                  EFFECTIVE    SOURCES
# joshjohanning         ADMIN        org-member(ADMIN), team:admin-team(WRITE), team:approver-team(WRITE)
# FluffyCarlton         MAINTAIN     direct(MAINTAIN), org-member(READ)
# joshgoldfishturtle    ADMIN        org-member(READ), team:compliance-team(ADMIN)


if [ -z "$2" ]; then
  echo "Usage: $0 <org> <repo> [affiliation] [hostname]"
  echo "  affiliation: OUTSIDE, DIRECT, ALL (default: ALL)"
  echo "  hostname: GitHub hostname (default: github.com)"
  exit 1
fi

org="$1"
repo="$2"
affiliation="${3:-ALL}"
hostname="${4:-github.com}"

# Map REST permission names (pull/push) to GraphQL-style names (READ/WRITE)
map_permission() {
  case "$1" in
    pull) echo "READ" ;;
    triage) echo "TRIAGE" ;;
    push) echo "WRITE" ;;
    maintain) echo "MAINTAIN" ;;
    admin) echo "ADMIN" ;;
    *) echo "$1" | tr '[:lower:]' '[:upper:]' ;;
  esac
}

# Get true team permissions via REST API and build a sed command to fix labels
sed_cmd=""
while IFS=$'\t' read -r slug perm; do
  mapped=$(map_permission "$perm")
  sed_cmd="${sed_cmd}s/team:${slug}\([^)]*\)/team:${slug}(${mapped})/g;"
done <<EOF
$(gh api --hostname "$hostname" --paginate "/repos/$org/$repo/teams?per_page=100" --jq '.[] | [.slug, .permission] | @tsv')
EOF

# Get source details via GraphQL
raw_output=$(gh api graphql --hostname "$hostname" --paginate -f owner="$org" -f repo="$repo" -f affiliation="$affiliation" -f query='
query ($owner: String!, $repo: String!, $affiliation: CollaboratorAffiliation!, $endCursor: String) {
  repository(owner:$owner, name:$repo) {
    name
    owner {
      login
    }
    collaborators(first: 100, affiliation: $affiliation, after: $endCursor) {
      pageInfo {
        endCursor
        hasNextPage
      }
      edges {
        node {
          login
        }
        permission
        permissionSources {
          permission
          source {
            ... on Team {
              type: __typename
              name: slug
            }
            ... on Repository {
              type: __typename
              name: name
            }
            ... on Organization {
              type: __typename
              name: login
            }
          }
        }
      }
    }
  }
}' --jq '
  .data.repository.collaborators.edges[] |
  .node.login as $user |
  .permission as $effective |
  (.permissionSources | map(select(.source.type == "Organization") | .permission)) as $org_perms |
  [.permissionSources[] |
    if .source.type == "Organization" then "org-member(\(.permission))"
    elif .source.type == "Team" then "team:\(.source.name)(\(.permission))"
    elif (.permission as $p | $org_perms | any(. == $p)) | not then
      # permissionSources only returns READ/WRITE/ADMIN - use effective for MAINTAIN/TRIAGE
      if .permission == "WRITE" and $effective == "MAINTAIN" then "direct(MAINTAIN)"
      elif .permission == "READ" and $effective == "TRIAGE" then "direct(TRIAGE)"
      else "direct(\(.permission))"
      end
    else empty
    end
  ] | unique | join(", ") |
  "\($user) | \($effective) | \(.)"
')

# Fix team permission labels using REST data
if [ -n "$sed_cmd" ]; then
  raw_output=$(echo "$raw_output" | sed -E "$sed_cmd")
fi

(echo "USER | EFFECTIVE | SOURCES" && echo "$raw_output") | column -t -s '|'
