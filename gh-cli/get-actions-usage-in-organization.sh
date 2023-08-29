#!/bin/bash

# Returns a list of all actions used in an organization using the SBOM API

# Example usage:
#  - ./get-actions-usage-in-repository.sh joshjohanning-org count-by-version txt > output.txt
#  - ./get-actions-usage-in-repository.sh joshjohanning-org count-by-action md > output.md

# count-by-version (default): returns a count of actions by version; actions/checkout@v2 would be counted separately from actions/checkout@v3
# count-by-action: returns a count of actions by action name; only care about actions/checkout usage, not the version

# Notes:
# - The count returned is the # of repositories that use the action - if a single repository uses the action 2x times, it will only be counted 1x
# - The script will take about 1 minute per 100 repositories

if [ $# -lt 1 ] || [ $# -gt 3 ] ; then
    echo "Usage: $0 <org> <count-by-version (default) | count-by-action> | <report format: txt (default) | csv | md>"
    exit 1
fi

org=$1
count_method=$2
report_format=$3

if [ -z "$count_method" ]; then
    count_method="count-by-version"
fi

if [ -z "$report_format" ]; then
    report_format="txt"
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

# if report_format = md
if [ "$report_format" == "md" ]; then
    echo "## 🚀 Actions Usage in Organization: $org"
    echo ""
    echo "| Count | Action |"
    echo "| --- | --- |"
elif [ "$report_format" == "csv" ]; then
    echo "Count,Action"
fi

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

results=$(echo -e "$results" | sort | uniq -c | sort -nr | awk '{print $1 " " $2}')

# if report_format = md
if [ "$report_format" == "md" ]; then
  echo -e "${results[@]}" | awk '{print "| " $1 " | " $2 " |"}'
elif [ "$report_format" == "csv" ]; then
  echo -e "${results[@]}" | awk '{print $1 "," $2}'
else
  echo -e "${results[@]}"
fi
