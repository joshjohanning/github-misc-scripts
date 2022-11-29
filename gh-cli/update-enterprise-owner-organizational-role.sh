#!/bin/bash

# use `get-enterprise-id.sh` and `get-organization-id.sh` to get the owner_id

# organizationRole
# - DIRECT_MEMBER: The user is a member of the organization.
# - OWNER: The user is an administrator/owner of the organization.
# - UNAFFILIATED: The user is a not a member of the organization. (leave the organization)

gh api graphql -f enterprise_id='E_kgDNCRQ' -f organization_id='O_kgDOBT6wwQ' -f organization_role='OWNER' -f query='
mutation ($enterprise_id: ID! $organization_id: ID! $organization_role: RoleInOrganization!) { 
  updateEnterpriseOwnerOrganizationRole(input: { enterpriseId: $enterprise_id organizationId: $organization_id organizationRole: $organization_role}) { 
      clientMutationId
   } 
}'
