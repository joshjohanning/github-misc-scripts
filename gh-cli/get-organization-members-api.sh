#!/bin/bash

# need at least
# gh auth refresh -h github.com -s read:user

# get login and id
gh api /orgs/joshjohanning-org/members --paginate -q '.[] | {login: .login, id: .id}' | jq -r '"login: \(.login), id: \(.id)"'
