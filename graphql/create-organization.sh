#!/bin/bash

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer xxx" \
  --data '{ "query": "mutation ($enterprise_id: ID! $organization_name: String! $admin_logins: [String!]! $billing_email: String!) { createEnterpriseOrganization(input: { enterpriseId: $enterprise_id login: $organization_name billingEmail: $billing_email profileName: $organization_name adminLogins: $admin_logins }) { enterprise { name } organization { id name } } }", "variables":{ "enterprise_id": "xxx123", "organization_name": "my-org-name", "billing_email": "xxx@xxx.com", "admin_logins": [ "joshjohanning", "other-guy" ] } }'
