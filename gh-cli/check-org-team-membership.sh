#!/bin/bash

# Check if a user is a member of a specific team in an organization
# API https://api.github.com/orgs/ORG/teams/TEAM_SLUG/memberships/USERNAME
# Response code 200 if user is a member, 404 if not

# Usage: ./check-org-team-membership.sh <ORG> <TEAM_SLUG> <USERNAME>
# Example: ./check-org-team-membership.sh myorg security johndoe

set -e

# Check if required parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <ORG> <TEAM_SLUG> <USERNAME>"
    echo "Example: $0 myorg security johndoe"
    echo ""
    echo "Note: Requires 'gh' CLI to be installed and authenticated"
    exit 1
fi

ORG="$1"
TEAM_SLUG="$2"
USERNAME="$3"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required but not installed."
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: GitHub CLI is not authenticated."
    echo "Run 'gh auth login' to authenticate."
    exit 1
fi

echo "Checking if user '$USERNAME' is a member of team '$TEAM_SLUG' in organization '$ORG'..."

# Check team membership
if gh api "orgs/$ORG/teams/$TEAM_SLUG/memberships/$USERNAME" --silent 2>/dev/null; then
    echo "✓ User '$USERNAME' is a member of team '$TEAM_SLUG' in organization '$ORG'"
    exit 0
else
    echo "✗ User '$USERNAME' is NOT a member of team '$TEAM_SLUG' in organization '$ORG'"
    exit 1
fi