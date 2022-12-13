#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

# role
# - MEMBER: The user is a member of the organization.
# - ADMIN: The user is an administrator/owner of the organization.

gh api graphql -f enterpriseId='E_abc' -f organizationId='O_abc' -f userIds='U_abc' -f role='MEMBER' -f query='
mutation($enterpriseId: ID!, $organizationId: ID!, $userIds: [ID!]!, $role: OrganizationMemberRole) {
  addEnterpriseOrganizationMember(input: {enterpriseId: $enterpriseId, organizationId: $organizationId, userIds: $userIds, role: $role}) {
    users {
      id
      login
    }
  }
}'
