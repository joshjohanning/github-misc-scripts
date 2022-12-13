#!/bin/bash

gh api graphql -f query='
{
  user(login: "joshjohanning") {
    login
    createdAt
    contributionsCollection(from: "2019-07-17T00:00:00Z" to: "2020-06-17T00:00:00Z") {
      earliestRestrictedContributionDate
    }
  }
}'

# in a 1 year block, return the date of the first non-public contribution
