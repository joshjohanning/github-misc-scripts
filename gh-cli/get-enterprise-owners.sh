
#!/bin/bash

# gets a list of 

# gh cli's token needs to be able to admin enterprise - run this first if it can't
# gh auth refresh -h github.com -s admin:enterprise

# organizationRole
# - OWNER: The user is an administrator (owner) of the enterprise.
# - BILLING_MANAGER: The user is a billing manager of the enterprise.

if [ -z "$1" ]; then
  echo "Usage: $0 <enterprise>"
  echo "Example: ./get-enterprise-owners.sh avocado-corp"
  exit 1
fi

enterprise="$1"

gh api graphql --paginate -f enterpriseSlug=$enterprise  -f query='
query ($enterpriseSlug: String!, $endCursor: String) {
  enterprise(slug: $enterpriseSlug) {
		ownerInfo {
			admins(first: 100, role: OWNER, after: $endCursor) {
        nodes {
          login
        }
        pageInfo {
          endCursor
          hasNextPage
        }
      }
		}
  }
}' --template '{{range .data.enterprise.ownerInfo.admins.nodes}}{{.login}}{{"\n"}}{{end}}'
