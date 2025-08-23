#!/bin/bash

# Checks if a user is a collaborator in a given repository and determines if they have admin access.
#
# Usage:
#   ./check-repository-admin.sh <OWNER> <REPOSITORY> <USERNAME>
# Example:
#   ./check-repository-admin.sh octocat Hello-World johndoe
#
# Requirements:
#   - GitHub CLI (`gh`) must be installed and authenticated
#   - Token must have `repo` scope for private repositories
#   - The script uses the GitHub API and requires permission to view collaborators and permissions for the repository

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <OWNER> <REPOSITORY> <USERNAME>"
    echo "Example: $0 octocat Hello-World johndoe"
    echo ""
    echo "Note: Requires 'gh' CLI to be installed and authenticated"
    exit 1
fi

OWNER="$1"
REPOSITORY="$2"
USERNAME="$3"

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

echo "Checking if user '$USERNAME' is a collaborator in repository '$OWNER/$REPOSITORY'..."

# Step 1: Check if user is a collaborator
if gh api --paginate "repos/$OWNER/$REPOSITORY/collaborators/$USERNAME" --silent 2>/dev/null; then
    echo "✓ User '$USERNAME' is a collaborator in '$OWNER/$REPOSITORY'"
    
    # Step 2: Check user's permission level
    echo "Checking permission level..."
    PERM_RESPONSE=$(gh api --paginate "repos/$OWNER/$REPOSITORY/collaborators/$USERNAME/permission" 2>/dev/null)
    
    if command -v jq &> /dev/null; then
        PERMISSION=$(echo "$PERM_RESPONSE" | jq -r '.permission')
    else
        PERMISSION=$(echo "$PERM_RESPONSE" | grep -o '"permission":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -z "$PERMISSION" ] || [ "$PERMISSION" = "null" ]; then
        echo "⚠ Could not determine permission level"
        echo "API Response: $PERM_RESPONSE"
        exit 1
    fi
    
    echo "Permission level: $PERMISSION"
    
    if [ "$PERMISSION" = "admin" ]; then
        echo "✓ User '$USERNAME' has ADMIN access to '$OWNER/$REPOSITORY'"
        exit 0
    else
        echo "✗ User '$USERNAME' does NOT have admin access to '$OWNER/$REPOSITORY' (has '$PERMISSION' permission)"
        exit 1
    fi
    
else
    echo "✗ User '$USERNAME' is NOT a collaborator in '$OWNER/$REPOSITORY' or an error occurred"
    exit 1
fi
