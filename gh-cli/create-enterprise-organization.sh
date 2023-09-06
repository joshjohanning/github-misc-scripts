#!/bin/bash

if [ -z "$3" ]; then
  echo "Usage: $0 <enterprise> <org> <billing_email>"
  echo "Example: ./create-enterprise-organization.sh avocado-corp joshjohanning-org-test-1 myemail@domain.com"
  exit 1
fi

# adds ID of user running the script as an org admin

enterprise="$1"
org="$2"
billing_email="$3"

user=$(gh api user --jq .login)
admin_logins=$(jq -c -n --arg admin "$user" '[$admin]')

enterprise_id=$(gh api graphql -H X-Github-Next-Global-ID:1 -f enterprise="$enterprise" -f query='
query ($enterprise: String!)
  { enterprise(slug: $enterprise) { 
    id 
  } 
}
' --jq '.data.enterprise.id')

gh api graphql -F enterprise_id="$enterprise_id" -F organization_name="$org" -F admin_logins="$admin_logins" -F billing_email="$billing_email" -f query='
mutation ($enterprise_id: ID! $organization_name: String! $admin_logins: [String!]! $billing_email: String!) { 
  createEnterpriseOrganization(input: { enterpriseId: $enterprise_id login: $organization_name billingEmail: $billing_email profileName: $organization_name adminLogins: $admin_logins }) { 
    enterprise { 
      name 
    } 
    organization { 
      id 
      name 
    } 
  } 
}'
