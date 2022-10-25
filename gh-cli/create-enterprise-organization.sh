#!/bin/bash

gh api graphql -f enterprise_id='MDEwOkVudGVycHJpc2UyMzI0' -f organization_name='my-organization-name' -f admin_logins='["my-username"]' -f billing_email='myemail@domain.com' -f query='
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
