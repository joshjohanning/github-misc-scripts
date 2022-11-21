#!/bin/bash

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

# organizationRole
# - DIRECT_MEMBER: The user is a member of the organization.
# - OWNER: The user is an administrator/owner of the organization.
# - UNAFFILIATED: The user is a not a member of the organization.

gh api graphql --paginate -f enterpriseSlug='avocado-corp' -f organizationRole='OWNER' -f query='
query ($enterpriseSlug: String!, $organizationRole: RoleInOrganization!, $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
    organizations(first: 100, viewerOrganizationRole: $organizationRole, after: $endCursor) {
      nodes {
        name
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}'
