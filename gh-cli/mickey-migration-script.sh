#!/bin/bash

# Purpose
# This script should be run after performing a migration from GHEC to GHEC/EMU. It may
# work for other scenarios, but has not been tested. The purpose of this script is to 
# copy the security from the source org to the target org. This includes teams and repos.

# you can use get-organization-members.sh to get a list of users in the org
# you can use gh api /orgs/mickeygoussetorg/repos | jq -r '.[].name' to get repo list for org
# gh api /orgs/mickeygoussetorg/teams | jq -r '.[].name' to get team list for org

# Assumptions with this script
# - The teams have been created in the target org 
# - The repos have been migrated to the target org
# - A CSV mapping file for source teams and target teams exists 
# - A CSV mapping file for source repos and target repos exists
# - Teams are only 1 level deep. It "may" work for multiple levels, but not tested

source_org="mickeygoussetorg"
target_org="mickeygoussetpleaseworkmigrationorg"
team_mapping_file="internal/team-mappings.csv"
repo_mapping_file="internal/repo-mappings.csv"

# STEP 1: Get the list of source teams
source_teams=$(gh api /orgs/$source_org/teams | jq -r '.[].name')

for team in $source_teams; do
    echo $team
done

# STEP 2: Get the list of source repos
source_repos=$(gh api /orgs/$source_org/repos | jq -r '.[].name')

for repo in $source_repos; do
    echo $repo
done

# STEP 3: For each team, run the copy-team-members.sh to populate the teams with users
for team in $source_teams; do
  echo "Team: $team"
  # STEP 3.1: Get the target team from the mapping file
  target_team=$(grep "^$team," $team_mapping_file | awk -F ',' '{print $2}')
  echo "Target Team: $target_team"

  if [ -z "$target_team" ]; then
      echo "Error: $team not found in $team_mapping_file"
      exit 1
  fi

  echo $target_team
  # STEP 3.2: Run the copy-team-members.sh script
  ./copy-team-members.sh $source_org $team $target_org $target_team
done

# STEP 4: For each repo, run the copy-permissions-between-org-repos.sh to populate security for repos and teams
#         Make sure to have the user mapping file

for repo in $source_repos; do
  echo $repo
  cat $repo_mapping_file
  # STEP 4.1: Get the target repo from the mapping file
  target_repo=$(grep "^$repo," $repo_mapping_file | awk -F ',' '{print $2}')
   if [ -z "$target_repo" ]; then
      echo "Error: $repo not found in $repo_mapping_file"
      echo $target_repo
      exit 1
  fi
  echo $target_repo
  # STEP 3.2: Run the copy-permissions-between-org-repos.sh script
  # don't forget to set the MAP_USER_SCRIPT environment variable and create the user mapping file
  ./copy-permissions-between-org-repos.sh $source_org $repo $target_org $target_repo
done

# STEP 5: Done. Security should mirror what was in the old system
echo "Done"