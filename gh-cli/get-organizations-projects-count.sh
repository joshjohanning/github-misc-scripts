#!/bin/bash

if [ $# -ne 1 ]; then
    echo "usage: $0 <enterprise slug>"
    exit 1
fi

enterprise=$1

gh api graphql -f enterprise="$enterprise" --paginate -f query='query($enterprise:String!, $endCursor: String) { 
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