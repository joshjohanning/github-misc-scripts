#!/bin/bash

gh api --paginate /orgs/joshjohanning-org/teams/approver-team/members --jq='.[] | [.login] | join(",")' # the join removes the "[" and "]" from the results
