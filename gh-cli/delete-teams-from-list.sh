#!/bin/bash

# Deletes teams in an organization from a CSV input list

# Need to run this to be able to delete teams: gh auth refresh -h github.com -s admin:org

# Usage: 
# Step 1: Create a list of teams in a csv file, 1 per line, with a trailing empty line at the end of the file
#     - child teams should have a slash in the name, e.g. test1-team/test1-1-team
#     - !!! Important !!! Note that if a team has child teams, all of the child teams will be deleted as well
#     - DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE
# Step 2: ./delete-teams-from-list.sh teams.csv <org>

# Example input file:
# 
# test11-team
# test22-team
# test11-team/test11111-team
# test11-team/test11111-team/textxxx-team

if [ $# -lt "2" ]; then
    echo "Usage: $0 <teams-file-name> <org>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

filename="$1"
org="$2"

while read -r repofull ; 
do
    read -ra data <<< "$repofull"

    team=${data}
    echo "Deleting team: $team"

    if [[ $team == *"/"* ]]; then
        child_team=$(echo $team | rev | cut -d'/' -f1 | rev)
        parent_team=$(echo $team | rev | cut -d'/' -f2 | rev)
        team=$child_team

        echo "  - parent team: $parent_team"
        echo "  - child team: $child_team"
    fi

    response=$(gh api \
      --method DELETE \
      -H "Accept: application/vnd.github+json" \
      /orgs/$org/teams/$team)

    echo $response

done < "$filename"
