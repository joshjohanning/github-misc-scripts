#!/bin/bash

# Gets a list of `workflow_dispatch` inputs used to queue a workflow run since it's not available otherwise in the API

# Usage: ./get-workflow-dispatch-inputs.sh joshjohanning-org trigger-separate-workflow workflow-b.yml 1

## See also: https://stackoverflow.com/questions/71155641/github-actions-how-to-view-inputs-for-workflow-dispatch

if [ $# -lt 3 ]
  then
    echo "usage: $(basename $0) <org> <repo> <workflow-file-name> <limit>"
    exit 1
fi

# to do:
# - add extra properties to the object, like:
#  - name/displayName (issues with spaces in the loop)
#  - actor (not in gh run list command)
#  - duration (might have to calculate from startedAt to updatedAt)
#  - number (workflow run number)
# - remove trailing comma from inputs object

ORG=$1
REPO=$2
WORKFLOW=$3
if [ -z "$4" ]; then LIMIT=1; else LIMIT=$4; fi

LOGDIR=./logsTEMP
LOGZIP=logsTEMP.zip

runs="$(gh run list -R $ORG/$REPO -w $WORKFLOW --limit $LIMIT --json databaseId,createdAt,workflowName,conclusion --jq '.[]')"

for run in $runs; do
  runId=$(echo "$run" | jq -r '.databaseId')
  createdAt=$(echo $run | jq -r '.createdAt')
  workflowName=$(echo $run | jq -r '.workflowName')
  conclusion=$(echo $run | jq -r '.conclusion')
  gh api /repos/$ORG/$REPO/actions/runs/$runId/logs > $runId$LOGZIP
  unzip -q $runId$LOGZIP -d $LOGDIR
  jobs=$(find $LOGDIR -maxdepth 1 -type f -not -name "*(*")
  for job in $jobs; do
    input="[\n  {\n    \"workflowName\": \"$workflowName\",\n    \"workflowId\": \"$runId\",\n$(sed -n '/"inputs": {/,/}/p;' $job | sed '/}/q' )\n    \"createdAt\": \"$createdAt\",\n    \"conclusion\": \"$conclusion\"\n  }\n],"
    echo -e "$input"
  done

  rm -f $runId$LOGZIP
  rm -rf $LOGDIR
done
