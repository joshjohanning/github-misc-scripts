#!/bin/bash

# this removes ALL branch protection status checks from a branch protection rule

gh api -X DELETE /repos/joshjohanning-org/circleci-test/branches/main/protection/required_status_checks \
