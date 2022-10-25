#!/bin/bash
# DOT NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE

# Usage: 
# Step 1: Create a list of users in a csv file, 1 per line, with a trailing empty line at the end of the file (or use ./generate-users-from-team <org> <team>)
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

while read -r repofull ; 
do
    IFS='/' read -ra data <<< "$repofull"

    user=${data[0]}

    echo $"Removing $user from $org"
    gh api --method DELETE /orgs/$org/memberships/$user
    
done < "$filename"
