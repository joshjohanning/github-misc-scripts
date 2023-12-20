#!/bin/bash

# this returns a list of organizations in an enterprise the user is a member of

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

if [ -z "$2" ]; then
  echo "Usage: $0 <enterprise> <user>"
  echo "Example: ./get-enterprise-organizations-for-user.sh joshjohanning"
  exit 1
fi

enterprise="$1"
user="$2"

gh api graphql --paginate -f enterpriseSlug=$enterprise -f login=$user -f query='
query ($enterpriseSlug: String!, $login: String!, $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
    members(query: $login, first: 1) {
      nodes {
        ... on EnterpriseUserAccount {
            login
            organizations(first: 100, after: $endCursor) {
              nodes {
                login
              }
              pageInfo {
                endCursor
                hasNextPage
              }
            }
        }
      }
    }
  }
}' | jq -s -r '{login: .[0].data.enterprise.members.nodes[0].login, organizations: [.[].data.enterprise.members.nodes[0].organizations.nodes[].login]}'
