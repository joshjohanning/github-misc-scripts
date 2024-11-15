#!/bin/bash

# Updates / sets the issue type for an issue

if [ -z "$4" ]; then
  echo "Usage: $0 <org> <repo> <issue-number> <type>"
  echo "Example: ./update-issue-issue-type.sh joshjohanning-org migrating-ado-to-gh-issues-v2 5 'user story'"
  exit 1
fi

org="$1"
repo="$2"
issue_number="$3"
type=$(echo "$4" | tr '[:upper:]' '[:lower:]')

# Define color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fetch issue types and filter to get the ID where name equals $type_upper
issue_type_id=$(gh api graphql -H GraphQL-Features:issue_types -f owner="$org" -f query='
query($owner: String!) {
  organization(login: $owner) {
   issueTypes(first: 100) {
      nodes {
        id
        name
      }
    }
  }
}' | jq -r --arg type "$type" '.data.organization.issueTypes.nodes[] | select(.name | ascii_downcase == $type) | .id')

# Check if issue type ID was found
if [ -z "$issue_type_id" ]; then
  echo "Issue type '$type' not found in organization '$org'."
  exit 1
fi

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

# Set the issue type on the issue
gh api graphql -H GraphQL-Features:issue_types -f issueId="$issue_id" -f issueTypeId="$issue_type_id" -f query='
mutation($issueId: ID!, $issueTypeId: ID!) {
  updateIssueIssueType(input: {issueId: $issueId, issueTypeId: $issueTypeId}) {
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
  echo "Issue type set to '$type' for issue #$issue_number."
else
  echo -e "${RED}Failed to set issue type for issue $org/$repo#$issue_number.${NC}"
  exit 1
fi
