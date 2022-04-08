#!/bin/bash

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer ${PAT}" \
  --data-raw '{"query":"query getOrganization($org_name:String!) {organization(login: $org_name) {id name organizationBillingEmail}}","variables":{"org_name":"my-org-name"}}'
