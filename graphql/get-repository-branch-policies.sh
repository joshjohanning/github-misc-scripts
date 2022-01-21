#!/bin/bash

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer ${PAT}" \
  --data '{"query":"query { repository(owner:\"joshjohanning-org\", name:\"test-repo\") { branchProtectionRules(first: 100) { nodes { pattern, id matchingRefs(first: 100) { nodes { name } } } } } }","variables":{}}'
