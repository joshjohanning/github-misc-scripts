#!/bin/bash

# Gets the issue type of an issue

if [ -z "$3" ]; then
  echo "Usage: $0 <org> <repo> <issue-number>"
  echo "Example: ./get-issue-type-of-issue.sh joshjohanning-org migrating-ado-to-gh-issues-v2 5"
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
issue=$(gh api graphql -H GraphQL-Features:issue_types -f owner="$org" -f repository="$repo" -F number="$issue_number" -f query='
query ($owner: String!, $repository: String!, $number: Int!) {
  repository(owner: $owner, name: $repository) {
    issue(number: $number) {
      title
      number
      url
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

# Extract and format the issue details using jq
formatted_issue=$(echo "$issue" | jq -r '
  .data.repository.issue | {
    title: .title,
    number: .number,
    url: .url,
    id: .id,
    issueType: .issueType.name
  }')

# Print the formatted issue details
echo "$formatted_issue" | jq .

# Check if issue type is null and print a warning
issue_type=$(echo "$formatted_issue" | jq -r '.issueType')
if [ "$issue_type" = "null" ]; then
  echo -e "${YELLOW}Warning: No issue type for $org/$repo#$issue_number.${NC}"
fi
