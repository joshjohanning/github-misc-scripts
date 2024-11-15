#!/bin/bash

# Gets a list of sub-issues from an issue

if [ -z "$3" ]; then
  echo "Usage: $0 <org> <repo> <issue-number>"
  echo "Example: ./get-sub-issues-of-issue.sh joshjohanning-org migrating-ado-to-gh-issues-v2 5"
  exit 1
fi

org="$1"
repo="$2"
issue_number="$3"

# Define color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Fetch the issue ID given the issue number
issue_id=$(gh api graphql -f owner="$org" -f repository="$repo" -F number="$issue_number" -f query='
query ($owner: String!, $repository: String!, $number: Int!) {
  repository(owner: $owner, name: $repository) {
    issue(number: $number) {
      id
    }
  }
}' --jq '.data.repository.issue.id')

# Check if the query was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Issue #$issue_number not found in $org/$repo${NC}"
  exit 1
fi

# Get the sub-issues for the issue
sub_issues=$(gh api graphql --paginate -H GraphQL-Features:sub_issues -H GraphQL-Features:issue_types -f issueId="$issue_id" -f query='
query($issueId: ID!, $endCursor: String) {
  node(id: $issueId) {
    ... on Issue {
      subIssues(first: 100, after: $endCursor) {
        totalCount
        nodes {
          title
          number
          url
          id
          issueType {
            name
          }
        }
        pageInfo { 
          hasNextPage 
          endCursor 
        }
      }
    }
  }
}')

# Check if the gh api graphql command was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to get sub-issues for $org/$repo#$issue_number.${NC}"
  exit 1
fi

# Combine the results using jq
combined_result=$(echo "$sub_issues" | jq -s '
  {
    totalCount: .[0].data.node.subIssues.totalCount,
    issues: (map(.data.node.subIssues.nodes) | add | map(.issueType = .issueType.name))
  }')

# Print the combined result as a colorized JSON object
echo "$combined_result" | jq .

# Check if total is 0 and print a warning
total=$(echo "$combined_result" | jq -r '.totalCount')
if [ "$total" -eq 0 ]; then
  echo -e "${YELLOW}Warning: The total number of sub-issues for $org/$repo#$issue_number is 0.${NC}"
fi
