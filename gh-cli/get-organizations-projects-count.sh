#!/bin/bash

# gets the projects count for all organizations in an enterprise

# need: `gh auth refresh -h github.com -s read:org -s read:enterprise`

# note: format is tsv

if [ $# -lt 1 ]; then
    echo "usage: $0 <enterprise-slug> <hostname> > output.tsv"
    exit 1
fi

enterprise=$1
hostname=${2:-"github.com"}
export PAGER=""

echo -e "Organization\tProjectv2 Count"

gh api graphql -f enterprise="$enterprise" --paginate --hostname $hostname -f query='query($enterprise:String!, $endCursor: String) { 
  enterprise(slug:$enterprise) {
    organizations(first:100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name
        projectsV2(first:1) { totalCount }
      }
    }
  }
}'  --jq '.data.enterprise.organizations.nodes[] | [.name, .projectsV2.totalCount] | @tsv'
