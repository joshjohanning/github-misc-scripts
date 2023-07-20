#!/bin/bash

# Adds a CODEOWNERS file to the default branch in a CSV list of repositories

# Usage: 
# Step 1: Run ./generate-repositories-list.sh <org> > repos.csv 
#   - Or create a list of repos in a csv file, 1 per line, with a trailing empty line at the end of the file
#   - DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE
# Step 2: ./add-codeowners-file-to-repositories.sh repos.csv ./CODEOWNERS false
#
# Overwrite or append: 
# - Defaults to append
# - If you want to overwrite the CODEOWNERS file, pass true as the 3rd argument, otherwise, it will append to the existing file
#

if [ $# -lt "2" ]; then
    echo "Usage: $0 <reposfilename> <codeowners-file> [overwrite: true|false]"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Repo import file $1 does not exist"
    exit 1
fi

if [ ! -f "$2" ]; then
    echo "CODEOWNERS file $2 does not exist"
    exit 1
fi

filename="$1"
codeownersfile="$2"
overwrite="$3"

while read -r repofull ; 
do
    IFS='/' read -ra data <<< "$repofull"

    org=${data[0]}
    repo=${data[1]}

    echo "Checking $org/$repo ..."

    # check if it exists first - CODEOWNERS file can be in the root, .github, or docs folder
    if file=$(gh api /repos/$org/$repo/contents/CODEOWNERS 2>&1); then
        exists=1
        path="CODEOWNERS"
        message="Updating CODEOWNERS file"
    elif file=$(gh api /repos/$org/$repo/contents/.github/CODEOWNERS 2>&1); then
        exists=1
        path=".github/CODEOWNERS"
        message="Updating CODEOWNERS file"
    elif file=$(gh api /repos/$org/$repo/contents/docs/CODEOWNERS 2>&1); then
        exists=1
        path="docs/CODEOWNERS"
        message="Updating CODEOWNERS file"
    else
        exists=0
        path=CODEOWNERS
        message="Adding CODEOWNERS file"
    fi

    if [ $exists=1 ]; then
        sha=$(echo $file | jq -r '.sha')
        echo " ... CODEOWNERS file already exists"
        # if $overwrite is true, then delete the CODEOWNERS file
        if [ "$overwrite" != true ] ; then
            echo " ... replacing CODEOWNERS file"
            content=$(echo $file | jq -r '.content' | base64 -d)
            # create temp CODEOWNERS file and add existing to top
            echo "$content" | cat - $codeownersfile > ./CODEOWNERS.tmp
            codeownersfile=./CODEOWNERS.tmp
        fi
    else
        echo " ... codeowners file doesn't exist"
        sha=""
        codeownersfile=$codeownersfile
    fi

    # Commit the CODEOWNERS file
    echo " ... comitting $path file to $org/$repo"
    if response=$(gh api -X PUT /repos/$org/$repo/contents/$path -f message="$message" -f content="$(base64 -i $codeownersfile)" -f sha=$sha 2>/dev/null); then
        path=$(echo $response | jq -r '.content.path')
        sha=$(echo $response | jq -r '.content.sha')
        date=$(echo $response | jq -r '.commit.committer.date')
        echo " ... committed $path with sha $sha on $date"
    else
        error=$(echo $response | jq -r ".message")
        echo " ... failed to commit $path; $error"
    fi

    # Delete the temp CODEOWNERS file if it exists
    if [ -f "./CODEOWNERS.tmp" ]; then
        rm ./CODEOWNERS.tmp
    fi

done < "$filename"
