#!/bin/bash

# Sets the required status checks for a branch

# 15368 is the App ID for GitHub Actions as a check source
# 57789 is the App ID for GitHub Advanced Security as a check source
# 9426 is the App ID for Azure Pipelines as a check source
# `strict: true` means that branch needs to be up to date before merging

gh api -X PATCH /repos/joshjohanning-org/circleci-test/branches/main/protection/required_status_checks \
  --input - << EOF
{
  "checks": [
    {
      "context": "ci/circleci: say-hello"
    },
    {
      "context": "ci/circleci: test-go-2"
    },
    {
      "context": "build",
      "app_id": 15368
    },
    {
      "context": "CodeQL",
      "app_id": 57789
    },
    {
      "context": "joshjohanning-org.tailspin-spacegame-web-demo (Build BuildJob)",
      "app_id": 9426
    }
  ],
  "strict": true
}
EOF
