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
#   ./create-team-and-link-idp-group.sh [--secret] [--hostname <host>] <org> <team-name> <idp-group-name>
#
# Notes:
#   - The script paginates through external groups to find the target group
#   - If the IdP group is not found, the script exits with an error
#   - The team is created with 'closed' (visible to org members) privacy by default
#   - Pass --secret to create a 'secret' (only visible to team members) team
#   - For GHES / GHE Data Residency, set GH_HOST or pass --hostname before running

usage() {
  echo "Usage: $0 [--secret] [--hostname <host>] <org> <team-name> <idp-group-name>"
  echo ""
  echo "Example: $0 my-org my-team \"Engineering Team\""
  echo "         $0 --secret --hostname github.example.com my-org my-team \"Engineering Team\""
}

org=""
team_name=""
idp_group_name=""
privacy="closed"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --secret)
      privacy="secret"
      shift
      ;;
    --hostname)
      if [ -z "${2:-}" ]; then
        echo "Error: --hostname requires a hostname value" >&2
        usage
        exit 1
      fi
      GH_HOST="$2"
      export GH_HOST
      shift 2
      ;;
    --*)
      echo "Error: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "$org" ]; then
        org="$1"
      elif [ -z "$team_name" ]; then
        team_name="$1"
      elif [ -z "$idp_group_name" ]; then
        idp_group_name="$1"
      else
        echo "Error: too many positional arguments: $1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$org" ] || [ -z "$team_name" ] || [ -z "$idp_group_name" ]; then
  echo "Error: missing required arguments" >&2
  usage
  exit 1
fi

# --- Find the external IdP group by display name ---
echo "Searching for external group '$idp_group_name' in organization '$org'..."

group_id=$(gh api \
  --method GET \
  --paginate \
  "/orgs/$org/external-groups" \
  | jq -r --arg name "$idp_group_name" '[.groups[] | select(.group_name | ascii_downcase == ($name | ascii_downcase)) | .group_id] | first // empty')

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
delete_output=$(gh api \
  --method DELETE \
  "/orgs/$org/teams/$team_slug/memberships/$current_user" 2>&1)
delete_status=$?
if [ "$delete_status" -eq 0 ]; then
  echo "Removed '$current_user' from team '$team_slug'."
elif echo "$delete_output" | grep -q "404"; then
  echo "User '$current_user' was not a member of team '$team_slug' (this is OK)."
else
  echo "Error: failed to remove '$current_user' from team '$team_slug'." >&2
  echo "$delete_output" >&2
  exit 1
fi

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
