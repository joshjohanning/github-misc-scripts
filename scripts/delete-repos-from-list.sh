#!/bin/bash
# DOT NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE

# Need to run this to get the repo delete scope: gh auth refresh -h github.com -s delete_repo

# Usage: 
# Step 1: Run ./generate-repos.sh joshjohanning-org > repos.csv 
#    (or create a list of repos in a csv file, 1 per line, with a trailing empty line at the end of the file)
# Step 2: ./clean-up-repos.sh repos.csv

if [ $# -lt "1" ]; then
    echo "Usage: $0 <reposfilename>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

filename="$1"

while read -r repofull ; 
do
    IFS='/' read -ra data <<< "$repofull"

    org=${data[0]}
    repo=${data[1]}

    echo $"Deleting: $org/$repo"
    gh repo delete $org/$repo --confirm

done < "$filename"
