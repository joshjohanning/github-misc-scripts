#!/bin/bash

gh api /orgs/joshjohanning-org/installations --paginate --jq '.installations[].app_slug'
