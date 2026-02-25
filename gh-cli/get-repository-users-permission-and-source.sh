#!/bin/bash

# Returns the permission for everyone who can access a repository and how they
# access it (direct, team, organization)
#
# gh cli's token needs to be able to admin the organization - run this first if needed:
#   gh auth refresh -h github.com -s admin:org
#
# Usage:
#   ./get-repository-users-permission-and-source.sh <org> <repo> [affiliation]
#
# affiliation can be: OUTSIDE, DIRECT, ALL (default: ALL)

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <repo> [affiliation]"
  echo "  affiliation: OUTSIDE, DIRECT, ALL (default: ALL)"
  exit 1
fi

org="$1"
repo="$2"
affiliation="${3:-ALL}"

gh api graphql --paginate -f owner="$org" -f repo="$repo" -f affiliation="$affiliation" -f query='
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
' | (echo "USER | EFFECTIVE | SOURCES" && cat) | column -t -s '|'
