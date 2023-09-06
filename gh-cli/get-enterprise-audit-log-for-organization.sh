#!/bin/bash

# This queries the Enterprise audit log APIs to specifically return if features have been enabled or disabled in an organization since a given date

if [ -z "$2" ]; then
  echo "Usage: $0 <enterprise> <org> <date>"
  echo "Example: ./get-enterprise-audit-log-for-organization.sh avocado-corp joshjohanning-org 2023-09-05"
  exit 1
fi

enterprise="$1"
org="$2"
date="$3"

# if date is empty, default to yesterdays date
if [ -z "$date" ]; then
  date=$(gdate -d "yesterday" +%Y-%m-%d) # if on linux, change from gdate to date
fi

# take note of rate limits: Each audit log API endpoint has a rate limit of 1,750 queries per hour for a given combination of user and IP address
#   - may receive errors and partial results if user does not have admin rights to all organizations / repositories

gh api -X GET --paginate "/enterprises/$enterprise/audit-log" -f "phrase=org:$org+created:>=$date" -f per_page=100 | \
  sed 's/{"message":"Must have admin rights to Repository.","documentation_url":"https:\/\/docs.github.com\/rest\/enterprise-admin\/audit-log#get-the-audit-log-for-an-enterprise"}/]/g' | \
  jq '.[] | select(.action | test("disable[d]?|enable[d]?")) | {action, actor, org, "@timestamp"} | .["@timestamp"] /= 1000 | .["@timestamp"] |= strftime("%Y-%m-%d %H:%M:%S")' 
