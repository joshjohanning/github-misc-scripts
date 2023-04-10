#!/bin/bash

gh api -X POST /repos/joshjohanning-org/circleci-test/branches/main/protection/required_status_checks/contexts \
  --input - << EOF
{
  "contexts": [
    "ci/circleci: test-go-1"
  ]
}
EOF
