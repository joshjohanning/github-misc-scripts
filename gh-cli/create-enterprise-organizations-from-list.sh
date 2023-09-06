#!/bin/bash

# Creates organizations in an enterprise from a CSV input list (orgs-to-create.csv)

# DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE

# adds ID of user running the script as an org admin

if [ -z "$3" ]; then
  echo "Usage: $0 <enterprise> <org-csv-file> <billing_email>"
  echo "Example: ./create-enterprise-organizations-from-list.sh avocado-corp orgs.csv myemail@domain.com"
  exit 1
fi

enterprise="$1"
orgs="$2"
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

while read line;
do
gh api graphql -F enterprise_id="$enterprise_id" -F organization_name="$line" -F admin_logins="$admin_logins" -F billing_email="$billing_email" -f query='
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
  }';
done < $orgs
