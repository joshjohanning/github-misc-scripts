#!/bin/bash

# Adds users to an organization team from a CSV input list

# Usage: 
# Step 1: Create a list of user emails in a csv file, 1 per line, with a trailing empty line at the end of the file
#   - DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE
# Step 2: ./invite-users-to-organization-from-list.sh users.csv <org> <team>

if [ $# -lt "2" ]; then
    echo "Usage: $0 <users-file-name> <org>"
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
    IFS='/' read -ra data <<< "$repofull"

    user=${data[0]}

    echo "Adding user to org: $user"

    response=$(gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      /orgs/$org/invitations \
      -f "email=${user}" -f "role=direct_member")

    echo $response

done < "$filename"
