#!/bin/bash

# gets the discussions count for all organizations in an enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

# note: format is tsv

if [ $# -lt 1 ]; then
    echo "usage: $0 <enterprise slug> <hostname> > output.tsv"
    exit 1
fi

enterprise=$1
hostname=$2
export PAGER=""

# set hostname to github.com by default
if [ -z "$hostname" ]
then
  hostname="github.com"
fi

echo -e "Repository\tDiscussion Count"

# we can't do everything in a single call b/c we need to paginate orgs and then paginate repos in the next query (can't do double pagination with gh api)
organizations=$(gh api graphql --paginate --hostname $hostname -f enterpriseName="$enterprise" -f query='
query getEnterpriseOrganizations($enterpriseName: String! $endCursor: String) {
  enterprise(slug: $enterpriseName) {
    organizations(first: 100, after: $endCursor) {
      nodes {
        id
        login
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}' --jq '.data.enterprise.organizations.nodes[].login')

for org in $organizations
do
  gh api graphql --paginate --hostname $hostname -f orgName="$org" -f query='
  query getOrganizationRepositories($orgName: String! $endCursor: String) {
    organization(login: $orgName) {
      repositories(first: 100, after: $endCursor) {
        nodes {
          nameWithOwner
          discussions {
            totalCount
          }
        }
        pageInfo {
          endCursor
          hasNextPage
        }
      }
    }
  }' --jq '.data.organization.repositories.nodes[] | [.nameWithOwner, .discussions.totalCount] | @tsv'
done
