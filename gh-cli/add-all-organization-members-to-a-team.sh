#!/bin/bash

# gh cli's token needs to be able to admin org - run this first if it can't
# gh auth refresh -h github.com -s admin:org

# this script is currently cumulative-only; it won't remove any users from the team
# (but this shouldn't matter, if someone gets pulled from org they won't be in team anymore anyway)

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <team>"
  echo "Example: ./add-all-organization-members-to-a-team.sh joshjohanning-org all-users"
  exit 1
fi

org="$1"
team="$2"

# Define color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

members=$(gh api /orgs/$org/members --jq '.[].login' --paginate)

# loop thru each member and gracefully try to add them to a team
for member in $members; do
  echo "Adding $member to $team"
  if ! gh api -X PUT /orgs/$org/teams/$team/memberships/$member -f "role=member"; then
    echo -e "${RED}Failed to add $member to $team${NC}"
  fi
done
