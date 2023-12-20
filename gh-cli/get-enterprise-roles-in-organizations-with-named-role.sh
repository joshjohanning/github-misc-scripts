#!/bin/bash

# this gets the enterprise roles for the current user, e.g. which organization(s) they are an owner of

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

# organizationRole
# - DIRECT_MEMBER: The user is a member of the organization.
# - OWNER: The user is an administrator/owner of the organization.
# - UNAFFILIATED: The user is a not a member of the organization.

if [ -z "$2" ] || [ "$2" != "DIRECT_MEMBER" ] && [ "$2" != "OWNER" ] && [ "$2" != "UNAFFILIATED" ]; then
  echo "Usage: $0 <enterprise> <role: OWNER|DIRECT_MEMBER|UNAFFILIATED>"
  echo "Example: ./get-enterprise-roles-in-organizations-all-roles.sh avocado-corp OWNER"
  exit 1
fi

enterprise="$1"
role="$2"

gh api graphql --paginate -f enterpriseSlug=$enterprise -f organizationRole='OWNER' -f query='
query ($enterpriseSlug: String!, $organizationRole: RoleInOrganization!, $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
    organizations(first: 100, viewerOrganizationRole: $organizationRole, after: $endCursor) {
      nodes {
        login
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}'
