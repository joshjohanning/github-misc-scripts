#!/bin/bash

# this removes specific branch protection status check(s) from a branch protection rule

gh api -X DELETE /repos/joshjohanning-org/circleci-test/branches/main/protection/required_status_checks/contexts \
  --input - << EOF
{
  "contexts": [
    "ci/circleci: say-hello",
    "ci/circleci: test-go-1"
  ]
}
EOF
