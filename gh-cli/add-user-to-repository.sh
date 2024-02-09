#!/bin/bash

# Adds a user to a repo

function print_usage {
  echo "Usage: $0 <org> <repo> <user> <role>"
  echo "Example: ./add-user-to-repository.sh joshjohanning-org my-repo joshjohanning ADMIN"
  echo "Valid roles: ADMIN, MAINTAIN, WRITE, TRIAGE, READ"
  exit 1
}

if [ -z "$4" ]; then
  print_usage
fi

org="$1"
repo="$2"
user="$3"
permission=$(echo "$4" | tr '[:lower:]' '[:upper:]')

case "$permission" in
  "ADMIN" | "MAINTAIN" | "WRITE" | "TRIAGE" | "READ")
    ;;
  *)
    print_usage
    ;;
esac

gh api -X PUT /repos/$org/$repo/collaborators/$user -f permission=$permission
