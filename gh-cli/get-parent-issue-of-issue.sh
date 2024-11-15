#!/bin/bash

# Gets the parent issue of an issue

if [ -z "$3" ]; then
  echo "Usage: $0 <org> <repo> <issue-number>"
  echo "Example: ./get-parent-issue-of-issue.sh joshjohanning-org migrating-ado-to-gh-issues-v2 5"
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

# Get the parent issue for the issue
parent_issue=$(gh api graphql -H GraphQL-Features:sub_issues -H GraphQL-Features:issue_types -f issueId="$issue_id" -f query='
query($issueId: ID!) {
  node(id: $issueId) {
    ... on Issue {
      parent {
        title
        number
        url
        id
        issueType {
          name
        }
      }
    }
  }
}')

# Check if the gh api graphql command was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to get the parent issue for $org/$repo#$issue_number.${NC}"
  exit 1
fi

# Extract and format the parent issue details using jq
formatted_parent_issue=$(echo "$parent_issue" | jq -r '
  .data.node.parent | {
    title: .title,
    number: .number,
    url: .url,
    id: .id,
    issueType: .issueType.name
  }')

# Print the formatted parent issue details
echo "$formatted_parent_issue" | jq .

# Check if parent issue is null and print a warning
number=$(echo "$formatted_parent_issue" | jq -r '.number')
if [ "$number" = "null" ]; then
  echo -e "${YELLOW}Warning: No parent issue for $org/$repo#$issue_number.${NC}"
fi
