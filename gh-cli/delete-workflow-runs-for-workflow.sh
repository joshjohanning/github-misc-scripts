#!/bin/bash

# This DELETES *ALL* workflow runs for a particular workflow in a repo

# Can pass in a workflow file name or workflow ID

# EXAMPLES:
# - ./delete-workflow-runs-for-workflow.sh my-org my-repo docker-image.yml
# - ./delete-workflow-runs-for-workflow.sh my-org my-repo 66987321

if [ $# -ne 3 ]
  then
    echo "usage: $0 <org> <repo> <workflow-file-name-or-id>"
    exit 1
fi

org=$1
repo=$2
workflow=$3

gh api --paginate --jq ".workflow_runs[].id" repos/$org/$repo/actions/workflows/$workflow/runs | xargs -I{} gh api --silent --method DELETE repos/$org/$repo/actions/runs/{}
