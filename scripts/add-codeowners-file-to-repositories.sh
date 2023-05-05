#!/bin/bash
# DOT NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE

# Need to run this to get the repo delete scope: gh auth refresh -h github.com -s delete_repo

# Usage: 
# Step 1: Run ./generate-repos.sh <org> > repos.csv 
#    (or create a list of repos in a csv file, 1 per line, with a trailing empty line at the end of the file)
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
    echo "Codeowners file $2 does not exist"
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

    # check if it exists first
    # TO DO : check for all valid spots for CODEOWNERS file (docs, root, .github), right now just checks root
    if file=$(gh api /repos/$org/$repo/contents/CODEOWNERS 2>&1); then
        sha=$(echo $file | jq -r '.sha')
        echo " ... CODEOWNERS file already exists"
        # if $overwrite is true, then delete the CODEOWNERS file
        if [ "$overwrite" != true ] ; then
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
    echo "comitting CODEOWNERS file to $org/$repo"
    gh api /repos/$org/$repo/contents/CODEOWNERS -f message="Add CODEOWNERS file" -f content="$(base64 -i $codeownersfile)" -f sha=$sha -X PUT

    # Delete the temp CODEOWNERS file if it exists
    if [ -f "./CODEOWNERS.tmp" ]; then
        rm ./CODEOWNERS.tmp
    fi

done < "$filename"
