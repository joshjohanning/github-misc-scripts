#!/bin/bash

# Creates organizations in an enterprise from a CSV input list (orgs-to-create.csv)

# DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE

# Use ../gh-cli/get-enterprise-id.sh to get the enterprise id to use here

while read line;
do
gh api graphql -f enterprise_id='enterprise-graphql-guid' -f organization_name="$line" -f admin_logins='["my-username"]' -f billing_email='my@email.com' -f query='
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
done < orgs-to-create.csv
