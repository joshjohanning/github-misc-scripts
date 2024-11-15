#!/bin/bash

# Gets the sub-issues summary of an issue

if [ -z "$3" ]; then
  echo "Usage: $0 <org> <repo> <issue-number>"
  echo "Example: ./get-sub-issues-summary-of-issue.sh joshjohanning-org migrating-ado-to-gh-issues-v2 5"
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
sub_issue_summary=$(gh api graphql -H GraphQL-Features:sub_issues -f issueId="$issue_id" -f query='
query($issueId: ID!) {
  node(id: $issueId) {
    ... on Issue {
      subIssuesSummary {
        total
        completed
        percentCompleted
      }
    }
  }
}')

# Check if the gh api graphql command was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to get sub-issue summary for $org/$repo#$issue_number.${NC}"
  exit 1
fi

# Extract and format the sub-issue summary details using jq
formatted_sub_issue_summary=$(echo "$sub_issue_summary" | jq -r '
  .data.node.subIssuesSummary | {
    total: .total,
    completed: .completed,
    percentCompleted: .percentCompleted
  }')

# Print the formatted sub-issue summary details
echo "$formatted_sub_issue_summary" | jq .

# Check if total is 0 and print a warning
total=$(echo "$formatted_sub_issue_summary" | jq -r '.total')
if [ "$total" -eq 0 ]; then
  echo -e "${YELLOW}Warning: The total number of sub-issues for $org/$repo#$issue_number is 0.${NC}"
fi
