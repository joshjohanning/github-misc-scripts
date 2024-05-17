#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <org>"
    exit 1
fi

org="$1"

declare -A repos
while IFS= read -r repo_json; do
    visibility=$(echo "$repo_json" | jq -r '.visibility')
    repo_name=$(echo "$repo_json" | jq -r '.name')

    if [ "$visibility" = "public" ]; then
        echo "Public repo $repo_name Skipping it"
        continue
    fi    

    repos["$repo_name"]=0
done < <(gh api "orgs/$org/repos" --paginate --jq '.[] | {name: .name, visibility: .visibility}')

# Increment secrets count for all repos
function incrementAllRepos() {
    for repo in "${!repos[@]}"; do
        ((repos["$repo"]++))
    done
}

# Given a secret name increment secrets count for selected repos 
function incrementSelectedRepos() {
    secret_name="$1"

    while IFS= read -r repo_json; do
        repo_name=$(echo "$repo_json" | jq -r '.name')

        repos["$repo_name"]=$((repos["$repo_name"] + 1))
    done < <(gh api "orgs/$org/actions/secrets/$secret_name/repositories" --paginate --jq '.repositories[] | {name: .name}')
}

while read -r secret_json; do

    secret_name=$(echo "$secret_json" | jq -r '.name')
    visibility=$(echo "$secret_json" | jq -r '.visibility')

    if [ "$visibility" = "public" ]; then
        echo "$secret_name is available to public repos. Skipping it"
        continue
    fi

    if [ "$visibility" = "private" ] || [ "$visibility" = "all" ]; then
        incrementAllRepos
    elif [ "$visibility" = "selected" ]; then
        incrementSelectedRepos "$secret_name"
    fi

done < <(gh api "orgs/$org/actions/secrets" --paginate --jq '.secrets[] | {name: .name, visibility: .visibility}')

# dump count of secrets for each repo

echo -e "\nSecrets count for $org by repo:"
for repo in "${!repos[@]}"; do
    echo "$repo: ${repos["$repo"]} secrets"
done

