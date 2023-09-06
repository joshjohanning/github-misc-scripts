#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 <enterprise> <org> <optional: actor>"
  exit 1
fi

enterprise="$1"
org="$2"
actor="$3" # this is optional, but adding it can really filter down results

if [ -z "$actor" ]; then
  actor_field="-f \"phrase=actor:$actor\""
fi

# we are using JQ to look for when things have specifically been enable[d] or disable[d] at the organization level
gh api -X GET "/enterprises/$enterprise/audit-log" $actor_field -f per_page=100 | jq --arg org "$org" '.[] | select(.org == $org) | select(.action | test("disable[d]?|enable[d]?")) | {action, actor, org, "@timestamp"} | .["@timestamp"] /= 1000 | .["@timestamp"] |= strftime("%Y-%m-%d %H:%M:%S")'
