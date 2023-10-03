#!/bin/bash

# Adds a workflow file to the default branch in a CSV list of repositories

# Usage: 
# Step 1: Run ./generate-repositories-list.sh <org> > repos.csv 
#   - Or create a list of repos in a csv file, 1 per line, with a trailing empty line at the end of the file
#   - DO NOT REMOVE TRAILING NEW LINE IN THE INPUT CSV FILE
# Step 2: ./add-workflow-file-to-repositories.sh repos.csv ./docker-image.yml true 390793 41851701 ./my-app.2023-09-15.private-key.pem
#
# Overwrite or append: 
# - Defaults to append
# - If you want to overwrite the workflow file, pass true as the 3rd argument, otherwise, it will skip
#
# Prerequisites:
# 1. Install gh (brew install gh)
# 2. Authenticate with gh (gh auth login)
# 3. Have the following extension installed: gh extension install lindluni/gh-token
# 4. Create a GitHub App, grab its App ID, Installation ID, and generate a private key (App will need contents: write, workflow: write, and be installed in the repo(s) you want to add the workflow file to)
# 5. Run the script
#

set -e

if [ $# -lt "6" ]; then
    echo "Usage: $0 <repos-list-file> <workflow-file> <overwrite: true|false> <app-id> <installation-id> <private-key-path>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Repo import file $1 does not exist"
    exit 1
fi

if [ ! -f "$2" ]; then
    echo "Workflow file $2 does not exist"
    exit 1
fi

filename="$1"
workflow_file="$2"
overwrite="$3"
app_id="$4"
installation_id="$5"
private_key_path="$6"

echo "..." && echo ""

# get the friendly name of $filename
workflow_file_basename=$(basename -- "$workflow_file")

token=$(gh token generate --app-id $app_id --installation-id $installation_id --key "$private_key_path" --token-only)

while read -r repofull ; 
do
    IFS='/' read -ra data <<< "$repofull"

    org=${data[0]}
    repo=${data[1]}

    echo "Checking $org/$repo ..."

    # check if it exists first
    if file=$(GH_TOKEN=$token gh api /repos/$org/$repo/contents/.github/workflows/$workflow_file_basename 2>/dev/null); then
        exists=1
        message="Replacing workflow $workflow_file_basename"
    else
        exists=0
        message="Adding workflow $workflow_file_basename"
    fi

    if [ $exists=1 ]; then
        sha=$(echo $file | jq -r '.sha')
        echo " ... workflow $workflow_file_basename already exists"
        # if $overwrite is true, then delete the workflow file
        if [ "$overwrite" != true ] ; then
            echo " ... replacing workflow $workflow_file_basename"
        fi
    else
        echo " ... workflow $workflow_file_basename doesn't exist"
        sha=""
    fi

    # Commit the workflow file
    echo " ... comitting .github/workflows/$workflow_file_basename to $org/$repo"
    if response=$(GH_TOKEN=$token gh api -X PUT /repos/$org/$repo/contents/.github/workflows/$workflow_file_basename -f message="$message" -f content="$(base64 -i $workflow_file)" -f sha=$sha 2>/dev/null); then
        path=$(echo $response | jq -r '.content.path')
        sha=$(echo $response | jq -r '.content.sha')
        date=$(echo $response | jq -r '.commit.committer.date')
        echo " ... committed $path with sha $sha on $date"
    else
        error=$(echo $response | jq -r ".message")
        echo " ... failed to commit $path; $error"
    fi

    echo ""

done < "$filename"
