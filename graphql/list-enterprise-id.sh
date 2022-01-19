#!/bin/bash

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer xxx" \
  --data '{ "query": "query ($enterprise: String!){ enterprise(slug: $enterprise) { id } }", "variables": { "enterprise": "enterprise-slug" } }'
