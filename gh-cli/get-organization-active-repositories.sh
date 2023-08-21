#!/bin/bash

# gets an organization's active repositories in the last X days 
# (which repositories have been pushed to in the last X days)

if [ $# -ne 2 ]
  then
    echo "usage: $0 <org> <days> > repos.csv"
    exit 1
fi

org=$1
days=$2

repos=$(gh api -X GET /orgs/joshjohanning-org/repos --paginate -F per_page=100)

# header
echo "name,description,language,pushed_at"

for repo in $(echo "${repos}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${repo} | base64 --decode | jq -r ${1}
  }

  name=$(_jq '.name')
  description=$(_jq '.description')
  language=$(_jq '.language')
  pushed_at=$(_jq '.pushed_at')

  if [[ $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${pushed_at}" +%s) -gt $(date -v -${days}d +%s) ]]; then
    echo "${name},${description},${language},${pushed_at}"
  fi
done
