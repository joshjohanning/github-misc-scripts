#!/bin/bash

# Adds a team to a repo

function print_usage {
  echo "Usage: $0 <org> <repo> <team_slug> <role>"
  echo "Example: ./add-team-to-repository.sh joshjohanning-org my-repo my-team push"
  echo "Valid roles: admin, maintain, push (write), triage, pull (read)"
  exit 1
}

if [ -z "$4" ]; then
  print_usage
fi

org=$1
repo=$2
team=$3
permission=$(echo "$4" | tr '[:upper:]' '[:lower:]')

case "$permission" in
  "admin" | "maintain" | "push" | "triage" | "pull")
    ;;
  *)
    print_usage
    ;;
esac

# https://docs.github.com/en/rest/teams/teams?apiVersion=2022-11-28#add-or-update-team-repository-permissions

gh api --method PUT "orgs/$org/teams/$team/repos/$org/$repo" -f permission="$permission"
