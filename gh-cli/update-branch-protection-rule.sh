#!/bin/bash

# see also: https://github.com/orgs/community/discussions/24758

gh api -X PUT /repos/joshjohanning-org/circleci-test/branches/main/protection \
  --input - << EOF
{
  "required_status_checks": null,
  "enforce_admins": null,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false,
    "required_approving_review_count": 1
  },
  "restrictions": null
}
EOF
