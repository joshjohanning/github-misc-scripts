#!/bin/bash

# Adds a .gitignore file to the default branch in a CSV list of repositories

# Usage: 
# Step 1: Run ./generate-repositories-list.sh <org> > repos.csv 
#    - Or create a list of repos in a csv file, 1 per line, with a trailing empty line at the end of the file\
#    - DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE
# Step 2: ./add-gitignore-file-to-repositories.sh repos.csv ./.gitignore false
#
# Overwrite or append: 
# - Defaults to append
# - If you want to overwrite the .gitignore file, pass true as the 3rd argument, otherwise, it will append to the existing file
#

if [ $# -lt "2" ]; then
    echo "Usage: $0 <reposfilename> <.gitignore-file> [overwrite: true|false]"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Repo import file $1 does not exist"
    exit 1
fi

if [ ! -f "$2" ]; then
    echo ".gitignore file $2 does not exist"
    exit 1
fi

filename="$1"
gitignorefile="$2"
overwrite="$3"

while read -r repofull ; 
do
    IFS='/' read -ra data <<< "$repofull"

    org=${data[0]}
    repo=${data[1]}

    echo "Checking $org/$repo ..."

    # check if it exists first
    if file=$(gh api /repos/$org/$repo/contents/.gitignore 2>&1); then
        sha=$(echo $file | jq -r '.sha')
        echo " ... .gitignore file already exists"
        # if $overwrite is true, then delete the gitignore file
        if [ "$overwrite" != true ] ; then
            content=$(echo $file | jq -r '.content' | base64 -d)
            # create temp .gitignore file and add existing to top
            echo "$content" | cat - $gitignorefile > ./.gitignore.tmp
            gitignorefile=./.gitignore.tmp
        fi
    else
        echo " ... .gitignore file doesn't exist"
        sha=""
        gitignorefile=$gitignorefile
    fi

    # Commit the .gitignore file
    echo " ... comitting .gitignore file to $org/$repo"
    gh api -X PUT /repos/$org/$repo/contents/.gitignore -f message="Adding .gitignore file" -f content="$(base64 -i $gitignorefile)" -f sha=$sha

    # Delete the temp gitignore file if it exists
    if [ -f "./.gitignore.tmp" ]; then
        rm ./.gitignore.tmp
    fi

done < "$filename"
