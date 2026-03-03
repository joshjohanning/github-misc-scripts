#!/bin/bash

# Creates an organization team in GitHub and links it to an Identity Provider
# (IdP) external group. The script lists external groups available in the
# organization, finds the target group by display name, creates a team, and
# then links the team to the external group.
#
# Prerequisites:
#   1. gh cli must be installed and authenticated (gh auth login)
#   2. Token must have the `admin:org` scope
#      - Run: gh auth refresh -h github.com -s admin:org
#   3. Enterprise has to be EMU or Data Residency
#      - Untested with non-EMU/DR enterprises; should work with SAML SSO / team synchronization similarly though
#
# Usage:
#   ./create-team-and-link-idp-group.sh <org> <team-name> <idp-group-name> [--secret]
#
# Notes:
#   - The script paginates through external groups to find the target group
#   - If the IdP group is not found, the script exits with an error
#   - The team is created with 'closed' (visible to org members) privacy by default
#   - Pass --secret to create a 'secret' (only visible to team members) team
#   - For GHES / GHE Data Residency, set GH_HOST before running

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <org> <team-name> <idp-group-name> [--secret]"
  echo ""
  echo "Example: $0 my-org my-team \"Engineering Team\""
  exit 1
fi

org="$1"
team_name="$2"
idp_group_name="$3"

privacy="closed"
if [ "${4}" = "--secret" ]; then
  privacy="secret"
fi

# --- Find the external IdP group by display name ---
echo "Searching for external group '$idp_group_name' in organization '$org'..."

group_id=$(gh api \
  --method GET \
  --paginate \
  "/orgs/$org/external-groups" \
  | jq -r --arg name "$idp_group_name" '.groups[] | select(.group_name | ascii_downcase == ($name | ascii_downcase)) | .group_id')

if [ -n "$group_id" ]; then
  echo "Found external group '$idp_group_name' with group_id: $group_id"
else
  echo "Error: external group '$idp_group_name' not found in organization '$org'."
  echo "Available groups:"
  gh api \
    --method GET \
    --paginate \
    "/orgs/$org/external-groups" \
    --jq '.groups[] | "  - \(.group_name) (id: \(.group_id))"'
  exit 1
fi

# --- Create the team ---
echo ""
echo "Creating team '$team_name' in organization '$org'..."

create_response=$(gh api \
  --method POST \
  "/orgs/$org/teams" \
  -f name="$team_name" \
  -f privacy="$privacy")

team_slug=$(echo "$create_response" | jq -r '.slug')

if [ -z "$team_slug" ] || [ "$team_slug" = "null" ]; then
  echo "Error: failed to create team '$team_name'."
  echo "$create_response" | jq .
  exit 1
fi

echo "Team '$team_name' created successfully (slug: $team_slug)."

# --- Remove the creating user from the team ---
# When a user creates a team, they are automatically added as a member.
# The team must have no explicit members before it can be linked to an
# external IdP group.
echo ""
echo "Removing creating user from team to allow external group linking..."

current_user=$(gh auth status --json hosts --jq '[.hosts[][]] | map(select(.active)) | .[0].login' 2>/dev/null)
if [ -z "$current_user" ]; then
  current_user=$(gh api /user --jq '.login')
fi
gh api \
  --method DELETE \
  "/orgs/$org/teams/$team_slug/memberships/$current_user" \
  --silent 2>/dev/null && echo "Removed '$current_user' from team '$team_slug'." \
  || echo "User '$current_user' was not a member of team '$team_slug' (this is OK)."

# --- Link the team to the external IdP group ---
echo ""
echo "Linking team '$team_slug' to external group '$idp_group_name' (group_id: $group_id)..."

link_response=$(gh api \
  --method PATCH \
  "/orgs/$org/teams/$team_slug/external-groups" \
  -F group_id="$group_id")

linked_group=$(echo "$link_response" | jq -r '.group_name // empty')

if [ -n "$linked_group" ]; then
  echo "Team '$team_slug' successfully linked to external group '$linked_group'!"
  echo "$link_response" | jq .
else
  echo "Error: failed to link team to external group."
  echo "$link_response" | jq .
  exit 1
fi
