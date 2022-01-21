#!/bin/bash

# repositoryId is the target repository id (source repository is not needed here)

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer ${PAT}" \
  --data '{"query":"mutation($input: TransferIssueInput!){ transferIssue(input: $input) { clientMutationId issue { id repository { url } repository { name } } } }","variables":{"input":{"issueId":"I_kwDOGgyPC85CNPf4","repositoryId":"R_kgDOGtuZKQ"}}}'
