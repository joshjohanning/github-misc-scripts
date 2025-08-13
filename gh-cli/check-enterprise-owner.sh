#!/bin/bash

# Check if a user is an enterprise admin
# API: https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/objects#enterpriseownerinfo
# Reference: https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/queries#enterprise

# Usage: ./check-enterprise-owner.sh <ENTERPRISE_SLUG> <USERNAME>
# Example: ./check-enterprise-owner.sh octocat johndoe

set -e

# Check if required parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <ENTERPRISE_SLUG> <USERNAME>"
    echo "Example: $0 octocat johndoe"
    echo ""
    echo "Note: Requires 'gh' CLI to be installed and authenticated"
    exit 1
fi

ENTERPRISE_SLUG="$1"
TARGET_USER="$2"

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

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for JSON parsing but not installed."
    echo "Install it with: brew install jq (on macOS) or your package manager"
    exit 1
fi

USER_FOUND=false
CURSOR=""
HAS_NEXT_PAGE=true

echo "Checking if user '$TARGET_USER' is an enterprise admin for '$ENTERPRISE_SLUG'..."

while [ "$HAS_NEXT_PAGE" = "true" ]; do
  # Build the GraphQL query with optional cursor
  if [ -z "$CURSOR" ]; then
    QUERY='
    query CheckEnterpriseAdmin($slug: String!) {
      enterprise(slug: $slug) {
        id
        name
        slug
        ownerInfo {
          admins(first: 100) {
            totalCount
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              login
              name
            }
          }
        }
      }
    }'
    RESPONSE=$(gh api graphql -f query="$QUERY" -f slug="$ENTERPRISE_SLUG" 2>/dev/null)
  else
    QUERY='
    query CheckEnterpriseAdmin($slug: String!, $cursor: String!) {
      enterprise(slug: $slug) {
        id
        name
        slug
        ownerInfo {
          admins(first: 100, after: $cursor) {
            totalCount
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              login
              name
            }
          }
        }
      }
    }'
    RESPONSE=$(gh api graphql -f query="$QUERY" -f slug="$ENTERPRISE_SLUG" -f cursor="$CURSOR" 2>/dev/null)
  fi

  # Check for errors in the response
  if [ $? -ne 0 ] || echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message // "Unknown error"' 2>/dev/null || echo "API call failed")
    echo "✗ Error accessing enterprise '$ENTERPRISE_SLUG': $ERROR_MSG"
    
    # Check for common error types
    if echo "$ERROR_MSG" | grep -q "Could not resolve to an Enterprise"; then
      echo "  Enterprise slug '$ENTERPRISE_SLUG' not found or not accessible"
    elif echo "$ERROR_MSG" | grep -q "Must have admin access"; then
      echo "  Current user does not have admin access to view enterprise admins"
    fi
    exit 1
  fi

  # Check if enterprise data exists
  if ! echo "$RESPONSE" | jq -e '.data.enterprise' > /dev/null 2>&1; then
    echo "✗ Enterprise '$ENTERPRISE_SLUG' not found or not accessible"
    exit 1
  fi

  # Extract data from response
  TOTAL_COUNT=$(echo "$RESPONSE" | jq -r '.data.enterprise.ownerInfo.admins.totalCount')
  HAS_NEXT_PAGE=$(echo "$RESPONSE" | jq -r '.data.enterprise.ownerInfo.admins.pageInfo.hasNextPage')
  CURSOR=$(echo "$RESPONSE" | jq -r '.data.enterprise.ownerInfo.admins.pageInfo.endCursor')
  
  # Check if target user is in current page
  ADMINS=$(echo "$RESPONSE" | jq -r '.data.enterprise.ownerInfo.admins.nodes[].login')
  
  PAGE_COUNT=$(echo "$RESPONSE" | jq -r '.data.enterprise.ownerInfo.admins.nodes | length')
  echo "Checking page with $PAGE_COUNT admins..."
  
  for admin in $ADMINS; do
    # Case-insensitive comparison
    if [ "$(echo "$admin" | tr '[:upper:]' '[:lower:]')" = "$(echo "$TARGET_USER" | tr '[:upper:]' '[:lower:]')" ]; then
      USER_FOUND=true
      echo "✓ User '$TARGET_USER' found as enterprise admin!"
      
      # Get full admin details
      ADMIN_NAME=$(echo "$RESPONSE" | jq -r --arg login "$admin" '.data.enterprise.ownerInfo.admins.nodes[] | select(.login == $login) | .name')
      echo "  Login: $admin"
      echo "  Name: $ADMIN_NAME"
      break 2  # Break out of both loops
    fi
  done
  
  # If no next page, break
  if [ "$HAS_NEXT_PAGE" = "false" ]; then
    break
  fi
done

# Final result
echo ""
echo "=== SUMMARY ==="
echo "Enterprise: $ENTERPRISE_SLUG"
echo "Total admins checked: $TOTAL_COUNT"
if [ "$USER_FOUND" = "true" ]; then
  echo "Result: ✓ '$TARGET_USER' IS an enterprise admin"
  exit 0
else
  echo "Result: ✗ '$TARGET_USER' is NOT an enterprise admin"
  exit 1
fi
