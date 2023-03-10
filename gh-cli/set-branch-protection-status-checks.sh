#!/bin/bash

gh api -X PUT /repos/joshjohanning-org/circleci-test/branches/main/protection/required_status_checks/contexts \
  --input - << EOF
{
  "contexts": [
    "ci/circleci: say-hello",
    "ci/circleci: test-go-2"
  ]
}
