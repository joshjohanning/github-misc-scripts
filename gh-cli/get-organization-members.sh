#!/bin/bash

# need at least
# gh auth refresh -h github.com -s read:user

gh api graphql --paginate -f owner='mickeygoussetorg' -f query='
query ($owner: String!, $endCursor: String) {
  organization(login: $owner) {
    membersWithRole(first: 100, after: $endCursor) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      edges {
        # OrganizationMemberRole
        # - MEMBER: The user is a member of the organization.
        # - ADMIN: The user is an administrator/owner of the organization.
        role
        node {
          id
          login
          name
          email
          organizationVerifiedDomainEmails(login: $owner)
        }
      }
    }
  }
}'
