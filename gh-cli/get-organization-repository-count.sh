#!/bin/bash

# count the number of repositories in an organization
gh api /orgs/joshjohanning-org/repos --paginate -F per_page=100 -X GET | jq -s 'map(.[]) | length'
