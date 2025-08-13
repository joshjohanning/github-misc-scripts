#!/bin/bash

# Check if user is a collaborator in the given repo
# API https://api.github.com/repos/OWNER/REPO/collaborators/USERNAME
# Response code 204 if user is a collaborator, 404 if not
#
# If a collaborator, check if user is a repo admin in the given repo
# API https://api.github.com/repos/OWNER/REPO/collaborators/USERNAME/permission
# Response code 200 if user has repo access permissions, otherwise not
# Response body will include "permission": "admin" if user is a repo admin

# Usage: ./check-repo-admin.sh <OWNER> <REPO> <USERNAME>
# Example: ./check-repo-admin.sh octocat Hello-World johndoe

set -e

# Check if required parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <OWNER> <REPO> <USERNAME>"
    echo "Example: $0 octocat Hello-World johndoe"
    echo ""
    echo "Note: Requires 'gh' CLI to be installed and authenticated"
    exit 1
fi

OWNER="$1"
REPO="$2"
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

echo "Checking if user '$USERNAME' is a collaborator in repository '$OWNER/$REPO'..."

# Step 1: Check if user is a collaborator
# Using --silent and --include flags to capture HTTP status
if gh api "repos/$OWNER/$REPO/collaborators/$USERNAME" --silent 2>/dev/null; then
    echo "✓ User '$USERNAME' is a collaborator in '$OWNER/$REPO'"
    
    # Step 2: Check user's permission level
    echo "Checking permission level..."
    PERM_RESPONSE=$(gh api "repos/$OWNER/$REPO/collaborators/$USERNAME/permission" 2>/dev/null)
    
    # Extract permission from JSON response using jq if available, otherwise use grep
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
    
    # Check if user has admin permission
    if [ "$PERMISSION" = "admin" ]; then
        echo "✓ User '$USERNAME' has ADMIN access to '$OWNER/$REPO'"
        exit 0
    else
        echo "✗ User '$USERNAME' does NOT have admin access to '$OWNER/$REPO' (has '$PERMISSION' permission)"
        exit 1
    fi
    
else
    # User is not a collaborator or an error occurred
    echo "✗ User '$USERNAME' is NOT a collaborator in '$OWNER/$REPO' or an error occurred"
    exit 1
fi