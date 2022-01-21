#!/bin/bash

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer ${PAT}" \
  --data '{"query":"mutation($input: DeleteBranchProtectionRuleInput!){ deleteBranchProtectionRule(input: $input) { clientMutationId } }","variables":{"input":{"branchProtectionRuleId":"BPR_kwDOGgyPC84BbN2g"}}}'
