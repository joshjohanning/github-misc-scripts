#!/bin/bash

# gets the settings for all organizations in an enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

# note: tsv is the default format
# tsv is a subset of fields, json is all fields

if [ $# -lt 1 ]
  then
    echo "usage: $0 <enterprise slug> <hostname> <format: tsv|json> > output.tsv/json"
    exit 1
fi

enterpriseslug=$1
hostname=$2
format=$3
export PAGER=""

# set hostname to github.com by default
if [ -z "$hostname" ]
then
  hostname="github.com"
fi

if [ -z "$format" ]
then
  format="tsv"
fi

organizations=$(gh api graphql --hostname $hostname --paginate -f enterpriseName="$enterpriseslug" -f query='
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

if [ "$format" == "tsv" ]; then
  echo -e "Org Login\tOrg Name\tOrg Desc\tDefault Repo Permission\tMembers Can Create Repos\t\tMembers Allowed Repos Creation Type\tMembers Can Create Public Repos\tMembers Can Create Private Repos\tMembers Can Create Internal Repos\tMembers Can Fork Private Repos"
fi

for org in $organizations
do
  if [ "$format" == "tsv" ]; then
    gh api "orgs/$org" --hostname $hostname --jq ". | [\"$org\", .name, .description, .default_repository_permission, .members_can_create_repositories, .members_allowed_repository_creation_type, .members_can_create_public_repositories, .members_can_create_private_repositories, .members_can_create_internal_repositories, .members_can_fork_private_repositories] | @tsv"
  else
    gh api "orgs/$org" --hostname $hostname
  fi
done
