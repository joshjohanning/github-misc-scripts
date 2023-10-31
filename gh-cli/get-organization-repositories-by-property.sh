#!/bin/bash

if [ $# -lt 2 ]; then
  echo "Usage: $0 <organization> <properties list>"
  echo "properties list: PROPERTY=VALUE PROPERTY2=VALUE2 ..."
  echo "Example: $0 octocat Production=true"
  exit 1
fi

organization=$1
shift 1

predicate=""
for property in "$@"; do
  name=$(echo "$property" | cut -d= -f1 -s)
  value=$(echo "$property" | cut -d= -f2 -s)

  # if name or value not defined
  if [ -z "$name" ] || [ -z "$value" ]; then
    echo "Invalid property: $property"
    echo "needs to be in the format: PROPERTY=VALUE"
    exit 1
  fi

  if [ -n "$predicate" ]; then
    predicate+=" and"
  fi
  
  predicate+=" any((.property_name | ascii_downcase) == (\"$name\" | ascii_downcase) and .value == \"$value\")"
done

gh api --paginate "orgs/$organization/properties/values" --jq ".[] | select(.properties | $predicate) | .repository_name"
