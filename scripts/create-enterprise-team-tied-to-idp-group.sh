#!/bin/bash

#
# Description:
#   Creates an enterprise team in GitHub and ties it to an Identity Provider (IdP)
#   group via SCIM. The script first paginates through all SCIM groups in the
#   enterprise to find the target IdP group by display name, then creates an
#   enterprise team linked to that group.
#
# Usage:
#   ./create-enterprise-team-tied-to-idp-group.sh <enterprise> <team-name> <idp-group-name> [api-url]
#
# Parameters:
#   enterprise      - The enterprise slug (e.g., "fabrikam")
#   team-name       - The name of the enterprise team to create (e.g., "MyTeam")
#   idp-group-name  - The display name of the IdP group to link (e.g., "Engineering Team")
#   api-url         - (Optional) The GitHub API base URL (default: https://api.github.com)
#
# Prerequisites:
#   1. curl and jq must be installed
#   2. Set the GH_PAT environment variable: export GH_PAT=ghp_abc
#      - Token must have the `admin:enterprise` scope
#   3. SCIM/SSO must be configured for the enterprise with IdP groups provisioned
#
# Notes:
#   - The script paginates through SCIM groups (100 per page) to find the target group
#   - If the IdP group is not found, the script exits with an error
#   - For GitHub Enterprise Server, pass the API URL as the 4th parameter
#     (e.g., https://github.example.com/api/v3)
#

set -e

# --- Input parameters ---
ENTERPRISE=$1    # Enterprise slug
TEAM=$2          # Enterprise team name to create
IDP_GROUP=$3     # IdP group display name to search for
API=${4:-"https://api.github.com"}  # GitHub API base URL (optional, defaults to github.com)

# --- Input validation ---
if [ -z "$3" ]; then
  echo "Usage: $0 <enterprise> <team-name> <idp-group-name> [api-url]"
  echo ""
  echo "Example: $0 fabrikam MyTeam \"Engineering Team\""
  exit 1
fi

if [ -z "$GH_PAT" ]; then
  echo "Error: GH_PAT environment variable is not set."
  echo "Set it with: export GH_PAT=ghp_abc"
  exit 1
fi

# --- Paginate through SCIM groups to find the target IdP group ---
PAGE_SIZE=100     # Number of SCIM groups to fetch per page
START_INDEX=1     # SCIM pagination start index (1-based)
GROUP_ID=""       # Will hold the SCIM group ID once found

while true; do
  RESPONSE=$(curl -s \
    -H "Authorization: Bearer $GH_PAT" \
    -H "Accept: application/scim+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API/scim/v2/enterprises/$ENTERPRISE/Groups?startIndex=$START_INDEX&count=$PAGE_SIZE")

  # Try to find the group in this page by matching the display name
  GROUP_ID=$(echo "$RESPONSE" | jq -r ".Resources[] | select(.displayName==\"$IDP_GROUP\") | .id")

  # If found, break out of the loop
  if [[ -n "$GROUP_ID" ]]; then
    break
  fi

  # Check if there are more pages to fetch
  TOTAL=$(echo "$RESPONSE" | jq -r ".totalResults")
  START_INDEX=$((START_INDEX + PAGE_SIZE))

  if [[ $START_INDEX -gt $TOTAL ]]; then
    echo "Group '$IDP_GROUP' not found in $TOTAL groups."
    break
  fi

  echo "Group not found in this page, fetching next page (startIndex=$START_INDEX)..."
done

echo "Finished searching for group '$IDP_GROUP'."
echo "GROUP_ID: $GROUP_ID"

# Exit if GROUP_ID was not found
if [[ -z "$GROUP_ID" ]]; then
  echo "Cannot create team without a valid GROUP_ID. Exiting."
  exit 1
fi

# --- Create the enterprise team tied to the IdP group ---
echo ""
echo "Creating enterprise team '$TEAM' with IdP group '$IDP_GROUP' (group_id: $GROUP_ID)..."
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_PAT" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API/enterprises/$ENTERPRISE/teams" \
  -d "$(jq -n --arg name "$TEAM" --arg gid "$GROUP_ID" '{name: $name, group_id: $gid}')")

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)  # Extract HTTP status code
BODY=$(echo "$CREATE_RESPONSE" | sed '$d')       # Extract response body

if [[ "$HTTP_CODE" == "201" ]]; then
  echo "Team '$TEAM' created successfully!"
  echo "$BODY" | jq .
else
  echo "Failed to create team. HTTP $HTTP_CODE"
  echo "$BODY" | jq .
  exit 1
fi