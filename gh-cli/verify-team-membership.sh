#!/bin/bash

if [ $# -lt 3 ]
  then
    echo "usage: $(basename $0) <org> <team> <user>"
    exit 1
fi

org=$1
team=$2
user=$3

members=$(gh api --paginate /orgs/$org/teams/$team/members --jq='.[] | [.login] | join(",")')

if [[ " ${members[*]} " =~ ${user} ]]; then
  echo "User is a member of the team."
else
  echo "User is not a member of the team."
fi
