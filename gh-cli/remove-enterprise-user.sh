#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

# Notes:
#
# 1. Get enterprise id: `./get-enterprise-id.sh`
# 2. Get user id by one of the following:
#     1. List org members and get the id from there: `./get-organization-members.sh`
#     2. Get user id: `./get-user-id.sh`

gh api graphql -f enterpriseId='E_kgDNCRQ' -f userId='U_kgDOBqwehQ' -f query='
mutation($enterpriseId: ID!, $userId: ID!) {
  removeEnterpriseMember(input: {enterpriseId: $enterpriseId, userId: $userId}) {
    user {
      id
      login
    }
  }
}'
