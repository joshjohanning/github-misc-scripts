#!/bin/bash

# Remove the issue type from an issue (set it to `null`)

if [ -z "$3" ]; then
  echo "Usage: $0 <org> <repo> <issue-number>"
  echo "Example: ./remove-issue-issue-type.sh joshjohanning-org migrating-ado-to-gh-issues-v2 5"
  exit 1
fi

org="$1"
repo="$2"
issue_number="$3"

# Define color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fetch the issue ID given the issue number
issue=$(gh api graphql -H GraphQL-Features:issue_types -f owner="$org" -f repository="$repo" -F number="$issue_number" -f query='
query ($owner: String!, $repository: String!, $number: Int!) {
  repository(owner: $owner, name: $repository) {
    issue(number: $number) {
      id
      issueType {
        name
      }
    }
  }
}')

# Check if the query was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Issue #$issue_number not found in $org/$repo${NC}"
  exit 1
fi

issue_id=$(echo "$issue" | jq -r '.data.repository.issue.id')
issue_type=$(echo "$issue" | jq -r '.data.repository.issue.issueType.name')

# Check if the issue type is already null
if [ "$issue_type" == "null" ]; then
  echo -e "${RED}The issue type is already null for issue #$issue_number in $org/$repo${NC}"
  exit 1
fi

# Remove the issue type on the issue
gh api graphql -H GraphQL-Features:issue_types -f issueId="$issue_id" -f query='
mutation($issueId: ID!) {
  updateIssueIssueType(input: {issueId: $issueId, issueTypeId: null}) {
    issue {
      title
      number
      url
      id
      issueType {
        name
      }
    }
  }
}'

# Check if the mutation was successful
if [ $? -eq 0 ]; then
  echo "Issue type removed for issue #$issue_number."
else
  echo -e "${RED}Failed to remove issue type for issue $org/$repo#$issue_number.${NC}"
  exit 1
fi
