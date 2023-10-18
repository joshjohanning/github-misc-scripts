#!/bin/bash

if [ $# -lt "1" ]; then
    echo "Usage: $0 <organization>"
    exit 1
fi

organization=$1

response=$(gh api graphql -f org="$organization" -f query='query ($cursor: String, $org: String!) {
  organization(login: $org) {
   queued : repositoryMigrations(after: $cursor, state: QUEUED) { totalCount	}
   notstarted: repositoryMigrations(after: $cursor, state: NOT_STARTED) {totalCount}
   inprogress: repositoryMigrations(after: $cursor, state: IN_PROGRESS) {totalCount}
   suceeded: repositoryMigrations(after: $cursor, state: SUCCEEDED) {totalCount}
   failed: repositoryMigrations(after: $cursor, state: FAILED) {totalCount}
   pendingvalidation: repositoryMigrations(after: $cursor, state: PENDING_VALIDATION) {totalCount}
   failedvalidation: repositoryMigrations(after: $cursor, state: FAILED_VALIDATION) {totalCount}
 }
}')

printf "%-20s %s\n" "Not started" "$(echo "$response" | jq -r '.data.organization .notstarted.totalCount')"
printf "%-20s %s\n" "Pending validation" "$(echo "$response" | jq -r '.data.organization .pendingvalidation.totalCount')"
printf "%-20s %s\n" "Failed validation" "$(echo "$response" | jq -r '.data.organization .failedvalidation.totalCount')"
printf "%-20s %s\n" "Queued" "$(echo "$response" | jq -r '.data.organization .queued.totalCount')"
printf "%-20s %s\n" "In progress" "$(echo "$response" | jq -r '.data.organization .inprogress.totalCount')"
printf "%-20s %s\n" "Succeeded" "$(echo "$response" | jq -r '.data.organization .suceeded.totalCount')"
printf "%-20s %s\n" "Failed" "$(echo "$response" | jq -r '.data.organization .failed.totalCount')"
echo "========================"
printf "%-20s %s\n" "Total" "$(echo "$response" | jq -r '[.. | .totalCount? | select(type=="number")] | add')"
