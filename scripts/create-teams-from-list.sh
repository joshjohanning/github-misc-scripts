#!/bin/bash
# DOT NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE

# Need to run this to be able to create teams: gh auth refresh -h github.com -s admin:org

# Usage: 
# Step 1: Create a list of teams in a csv file, 1 per line, with a trailing empty line at the end of the file
#           - child teams should have a slash in the name, e.g. test1-team/test1-1-team
#           - build out the parent structure in the input file before creating the child teams;
#               e.g. have the 'test1-team' come before 'test1-team/test1-1-team' in the file
# Step 2: ./create-teams-from-list.sh teams.csv <org>

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
    echo "Creating team: $team ..."

    # reset the parent_param
    parent_param=""

    # if the team is a child team, need to get the parent team id
    if [[ $team == *"/"* ]]; then
        child_team=$(echo $team | rev | cut -d'/' -f1 | rev)
        parent_team=$(echo $team | rev | cut -d'/' -f2 | rev)
        team=$child_team

        echo "  - parent team: $parent_team"
        echo "  - child team: $child_team"
        
        echo "  - ...getting parent team id..."
        parent_team_id=$(gh api \
            --method GET \
            -H "Accept: application/vnd.github+json" \
            /orgs/$org/teams/$parent_team \
            -q '.id')

        parent_param="-F parent_team_id=$parent_team_id"
        echo "  - ...okay now creating $team with parent of $parent_team (parent id: $parent_team_id)..."
    fi

    response=$(gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      /orgs/$org/teams \
      -f name="$team" -f privacy='closed' $parent_param)

    echo $response

done < "$filename"
