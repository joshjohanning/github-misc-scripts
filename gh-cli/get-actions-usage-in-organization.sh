#!/bin/bash

# Returns a list of all actions used in an organization using the SBOM API

# Example usage:
#  - ./get-actions-usage-in-repository.sh joshjohanning-org count-by-version
#  - ./get-actions-usage-in-repository.sh joshjohanning-org count-by-action

# count-by-version (default): returns a count of actions by version; actions/checkout@v2 would be counted separately from actions/checkout@v3
# count-by-action: returns a count of actions by action name; only care about actions/checkout usage, not the version

# Notes:
# - The count returned is the # of repositories that use the action - if a single repository uses the action 2x times, it will only be counted 1x
# - The script will take about 1 minute per 100 repositories

if [ $# -lt 1 ] || [ $# -gt 2 ] ; then
    echo "Usage: $0 <org> <count-by-version (default) | count-by-action>"
    exit 1
fi

org=$1
count_method=$2

if [ -z "$count_method" ]; then
    count_method="count-by-version"
fi

repos=$(gh api graphql --paginate -F org="$org" -f query='query($org: String!$endCursor: String){
organization(login:$org) {
    repositories(first:100,after: $endCursor) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        owner {
          login
        }
        name
      }
    }
  }
}' --template '{{range .data.organization.repositories.nodes}}{{printf "%s/%s\n" .owner.login .name}}{{end}}')

actions=()

for repo in $repos; do
    actions+=$(gh api repos/$repo/dependency-graph/sbom --jq '.sbom.packages[].externalRefs.[0].referenceLocator' 2>&1 | grep "pkg:githubactions" | sed 's/pkg:githubactions\///') || true
    actions+="\n"
done

# clean up extra spaces
results=$(echo -e "${actions[@]}" | tr -s '\n' '\n' | sed 's/\n\n/\n/g')

# if count_method=count-by-action, then remove the version from the action name
if [ "$count_method" == "count-by-action" ]; then
    results=$(echo -e "${results[@]}" | sed 's/@.*//g')
fi

echo -e "$results" | sort | uniq -c | sort -nr | awk '{print $1 " " $2}'
