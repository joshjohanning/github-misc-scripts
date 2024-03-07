#!/bin/bash

# summarizes the most recent migration imports for a given organization

# gh cli's token needs to be able to admin org - run this if it fails
# gh auth refresh -h github.com -s admin:org

if [ $# -lt "1" ]; then
    echo "Usage: $0 <organization>"
    exit 1
fi

organization=$1

if ! response=$(gh api graphql -f org="$organization" -f query='query ($org: String!) {
  organization(login: $org) {
   queued : repositoryMigrations(state: QUEUED) {totalCount}
   notstarted: repositoryMigrations(state: NOT_STARTED) {totalCount}
   inprogress: repositoryMigrations(state: IN_PROGRESS) {totalCount}
   suceeded: repositoryMigrations(state: SUCCEEDED) {totalCount}
   failed: repositoryMigrations(state: FAILED) {totalCount}
   pendingvalidation: repositoryMigrations(state: PENDING_VALIDATION) {totalCount}
   failedvalidation: repositoryMigrations(state: FAILED_VALIDATION) {totalCount}
 }
}') ; then
    echo "Error getting organization data from $organization"
    exit 1
fi

printf "%-20s %s\n" "Not started" "$(echo "$response" | jq -r '.data.organization .notstarted.totalCount')"
printf "%-20s %s\n" "Pending validation" "$(echo "$response" | jq -r '.data.organization .pendingvalidation.totalCount')"
printf "%-20s %s\n" "Failed validation" "$(echo "$response" | jq -r '.data.organization .failedvalidation.totalCount')"
printf "%-20s %s\n" "Queued" "$(echo "$response" | jq -r '.data.organization .queued.totalCount')"
printf "%-20s %s\n" "In progress" "$(echo "$response" | jq -r '.data.organization .inprogress.totalCount')"
printf "%-20s %s\n" "Succeeded" "$(echo "$response" | jq -r '.data.organization .suceeded.totalCount')"
printf "%-20s %s\n" "Failed" "$(echo "$response" | jq -r '.data.organization .failed.totalCount')"
echo "========================"
printf "%-20s %s\n" "Total" "$(echo "$response" | jq -r '[.. | .totalCount? | select(type=="number")] | add')"
