#!/bin/bash

## This script adds a specified team to a list of repositories with specified permissions.
## Make sure your repo_list_file contains entries in the format repository_name,permission, for example:
## repo1,admin
## repo2,push
## repo3,pull
##
## Usage:
##   ./add-team-to-repositories-from-list.sh <organization> <team_slug> <repo_list_file>
##
## Arguments:
##   organization    - The GitHub organization name
##   team_slug       - The slug of the team to add to the repositories
##   repo_list_file  - The file containing the list of repositories and permissions
##
## Example:
##   ./add-team-to-repositories-from-list.sh my-org my-team repos.csv
##
## Where repos.csv contains:
## repo1,admin
## repo2,push
## repo3,pull
##
## The available permissions for adding a team to repositories using the add-team-to-repositories-from-list.sh script are:
##
## pull - Read-only access to the repository.
## push - Read and write access to the repository.
## admin - Full access to the repository, including the ability to manage settings and users.
## maintain - Full access to the repository, with the ability to manage settings and users, but not delete the repository.
## triage - Read access to the repository, with the ability to manage issues and pull requests.
##
## These permissions correspond to the levels of access that can be granted to a team for a repository on GitHub.
## See https://docs.github.com/en/rest/teams/teams#add-or-update-team-repository-permissions for more information.
##
## Required Permissions:
##   - The user running this script must have admin access to the organization.
##   - The GitHub CLI (gh) must be authenticated with sufficient permissions to manage teams and repositories.



# Ensure GitHub CLI is authenticated
if ! gh auth status > /dev/null 2>&1; then
    echo "Please authenticate GitHub CLI using 'gh auth login'"
    exit 1
fi

# Check if the required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <organization> <team_slug> <repo_list_file>"
    exit 1
fi

ORG=$1
TEAM_SLUG=$2
REPO_LIST_FILE=$3

# Check if the repository list file exists
if [ ! -f "$REPO_LIST_FILE" ]; then
    echo "Repository list file not found: $REPO_LIST_FILE"
    exit 1
fi

# Read the repository list file and add the team to each repository with the specified permission
while IFS=, read -r REPO PERMISSION; do
    if [ -n "$REPO" ] && [ -n "$PERMISSION" ]; then
        echo "Adding team '$TEAM_SLUG' to repository '$REPO' in organization '$ORG' with permission '$PERMISSION'..."
        gh api -X PUT "/orgs/$ORG/teams/$TEAM_SLUG/repos/$ORG/$REPO" -f permission="$PERMISSION"
        if [ $? -eq 0 ]; then
            echo "Successfully added team '$TEAM_SLUG' to repository '$REPO' with permission '$PERMISSION'"
        else
            echo "Failed to add team '$TEAM_SLUG' to repository '$REPO' with permission '$PERMISSION'"
        fi
    fi
done < "$REPO_LIST_FILE"
