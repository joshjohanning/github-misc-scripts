#!/bin/bash

# Remove users from an organization from a CSV input list

# Usage: 
# Step 1: Create a list of users in a csv file, 1 per line, with a trailing empty line at the end of the file (or use ./generate-users-from-team <org> <team>)
#   - DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE
# Step 2: ./remove-users-from-org.sh <file> <org>

if [ $# -ne "2" ]; then
    echo "Usage: $0 <users-file-name> <org>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

filename="$1"
org="$2"
current_user=$(gh api /user -q '.login')

while read -r repofull ; 
do
    IFS='/' read -ra data <<< "$repofull"

    user=${data[0]}

    # if $user is logged in user, skip
    if [ "$user" == "$current_user" ]; then
        echo "Skipping current user $user"
        continue
    else
        echo $"Removing $user from $org"
        gh api --method DELETE /orgs/$org/memberships/$user
    fi
    
done < "$filename"
