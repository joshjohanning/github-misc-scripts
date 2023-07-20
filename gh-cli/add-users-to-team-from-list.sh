#!/bin/bash

# Adds users to an organization team from a CSV input list

# Usage: 
# Step 1: Create a list of users in a csv file, 1 per line, with a trailing empty line at the end of the file
#   - DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE
# Step 2: ./add-users-to-team-from-list.sh users.csv <org> <team>

if [ $# -lt "3" ]; then
    echo "Usage: $0 <users-file-name> <org> <team-slug>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

filename="$1"
org="$2"
team="$3"

filename="$1"

while read -r repofull ; 
do
    IFS='/' read -ra data <<< "$repofull"

    user=${data[0]}

    echo "Adding user to team: $user"

    response=$(gh api \
      --method PUT \
      -H "Accept: application/vnd.github+json" \
      /orgs/$org/teams/$team/memberships/$user \
      -f role='member')

    echo $response

done < "$filename"
