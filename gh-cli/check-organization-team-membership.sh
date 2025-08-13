#!/bin/bash

# Checks if a user is a member of a specific team in an organization using the GitHub API.
#
# Usage:
#   ./check-org-team-membership.sh <organization> <team-slug> <username>
#
# Example:
#   ./check-org-team-membership.sh my-organization security johndoe
#
# Requirements:
#   - GitHub CLI (`gh`) must be installed and authenticated
#   - Token must have `read:org` scope to view team membership
#   - Uses GitHub API endpoint: /orgs/{organization}/teams/{team-slug}/memberships/{username}
#   - This script does not paginate as the endpoint is for a single user/team
#
# Notes:
#   - Organization, team-slug, and username must be provided as input parameters

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <organization> <team-slug> <username>"
    echo "Example: $0 my-organization security johndoe"
    echo ""
    echo "Note: Requires 'gh' CLI to be installed and authenticated"
    exit 1
fi

organization="$1"
team_slug="$2"
username="$3"

if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required but not installed."
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: GitHub CLI is not authenticated."
    echo "Run 'gh auth login' to authenticate."
    exit 1
fi

echo "Checking if user '$username' is a member of team '$team_slug' in organization '$organization'..."

if gh api "orgs/$organization/teams/$team_slug/memberships/$username" --silent 2>/dev/null; then
    echo "✓ User '$username' is a member of team '$team_slug' in organization '$organization'"
    exit 0
else
    echo "✗ User '$username' is NOT a member of team '$team_slug' in organization '$organization'"
    exit 1
fi