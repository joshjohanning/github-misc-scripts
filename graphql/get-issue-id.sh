#!/bin/bash

curl -X POST 'https://api.github.com/graphql' \
  -H "Authorization: bearer ${PAT}" \
  --data '{"query":"query FindIssueID { repository(owner:\"joshjohanning-org\", name:\"test-repo\") {issue(number:1) { id } } }","variables":{}}'
