#!/bin/bash

# Verify if a specified user is a member of a team

members=$(gh api --paginate /orgs/joshjohanning-org/teams/approver-team/members --jq='.[] | [.login] | join(",")')

themember="joshjohanning"

if grep -q "$members" <<< "$themember"; then
  echo "member present"
else
  echo "member not present"
fi
