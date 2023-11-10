#!/bin/bash

# Usage
# ./recreate-security-in-repos-and-teams.sh --source-org mickeygoussetorg --target-org mickeygoussetpleaseworkmigrationorg --team-mapping-file team_mappings.csv --repo-mapping-file repo_mappings.csv

# Author
# @mickeygousset

# Purpose
  # This script should be run after performing a migration from GHEC to GHEC/EMU. It may
  # work for other scenarios, but has not been tested. The purpose of this script is to 
  # copy the security from the source org to the target org for the repositories and teams
  # listed in their respective CSV files

# There are multiple PreReqs for this script to work. They are listed below.

  # Set the following environment variables before running the script

    # SOURCE_TOKEN - Personal Access Token for the source org
    # TARGET_TOKEN - Personal Access Token for the target org
    # MAP_USER_SCRIPT - environment variable that points to a script that will map users from the source org to the target org. For this you should use __map_users_using_csv.sh

  # create a team mapping file, such as team_mappings.csv
  
    # The format of the file should be as follows:
      # source_team1,target_team1
      # source_team2,target_team2
      # source_team3,target_team3
    # you can run gh api orgs/YOURORGHERE/team | jq -r '.[].login' to get a list of users in the org to help with creating the file

  # create a repo mapping file, such as repo_mappings.csv
    
    # The format of the file should be as follows:
      # source_repo1,target_repo1
      # source_repo2,target_repo2
      # source_repo3,target_repo3
    # you can run gh api /orgs/YOURORGHERE/repos | jq -r '.[].name' to get a list of repos in the org to help with creating the file

  # create a user mapping file, such as user_mappings.csv. This file is used by the MAP_USER_SCRIPT script
  # and should be in the same folder as the MAP_USER_SCRIPT script
    
    # The format of the file should be as follows:
      # source_user1,target_user1
      # source_user2,target_user2
      # source_user3,target_user3
    # you can run gh api orgs/YOURORGHERE/members --jq '.login' to get a list of users in the org to help with creating the file

# Assumptions
  # - We are only going to migrate the teams and repos that are listed in the mapping files.
  # - The teams have been created in the target org 
  # - The repos have been migrated to the target org
  # - All users exist in the target org
  # - A CSV mapping file for source teams and target teams exists 
  # - A CSV mapping file for source repos and target repos exists
  # - A CSV mapping file for source users and target users exists
  # - Teams are only 1 level deep. It "may" work for multiple levels, but not tested


verbose=false
source_org=""
target_org=""
team_mapping_file=""
repo_mapping_file=""

while (( "$#" )); do
  case "$1" in
    --verbose)
      verbose=true
      shift
      ;;
    --source-org)
      source_org=$2
      shift 2
      ;;
    --target-org)
      target_org=$2
      shift 2
      ;;
    --team-mapping-file)
      team_mapping_file=$2
      shift 2
      ;;
    --repo-mapping-file)
      repo_mapping_file=$2
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

# STEP 1: For each team in the first column of the teams csv file, 
#          run copy-team-members.sh to populate the teams with users
echo "Adding Users To Teams"
source_teams=$(cut -d ',' -f 1 $team_mapping_file)
for team in $source_teams; do
  if $verbose; then
   echo $team
  fi
  # STEP 1.1: Get the target team from the mapping file
  target_team=$(grep "^$team," $team_mapping_file | awk -F ',' '{print $2}')
  echo "Source Team: $team"
  if [ -z "$target_team" ]; then
      echo "Error: $team not found in $team_mapping_file"
      exit 1
  fi
  echo "Target Team: $target_team"
  # STEP 1.2: Run the copy-team-members.sh script
  echo "Run copy-team-members.sh $source_org $team $target_org $target_team"
  ../../gh-cli/copy-team-members.sh $source_org $team $target_org $target_team
  echo "Done adding Source Team: $team to Target Team: $target_team"
  echo "**********"
done

# STEP 2: Get the list of source repos
echo "*****************************"
echo "*****************************"
echo "Adding Users and Teams to Repos"
source_repos=$(cut -d ',' -f 1 $repo_mapping_file)
for repo in $source_repos; do
  # STEP 2.1: Get the target repo from the mapping file
  target_repo=$(grep "^$repo," $repo_mapping_file | awk -F ',' '{print $2}')
  echo "Source Repo: $repo"
   if [ -z "$target_repo" ]; then
      echo "Error: $repo not found in $repo_mapping_file"
      exit 1
  fi
  echo "Target Repo: $target_repo"
  # STEP 2.2: Run the copy-permissions-between-org-repos.sh script
  # don't forget to set the MAP_USER_SCRIPT environment variable and create the user mapping file
  echo "Run copy-permissions-between-org-repos.sh $source_org $repo $target_org $target_repo"
  ../../gh-cli/copy-permissions-between-org-repos.sh $source_org $repo $target_org $target_repo
  echo "Done adding Source Repo: $repo to Target Repo: $target_repo"
  echo "**********"
done

# STEP 3: Done. Security should mirror what was in the old system
echo "*****************************"
echo "*****************************"
echo "Done"
