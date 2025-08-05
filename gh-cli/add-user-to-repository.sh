#!/bin/bash

# Adds a user to a repo

function print_usage {
  echo "Usage: $0 <org> <repo> <role> <user> [skip_invite_check]"
  echo "Example: ./add-user-to-repository.sh joshjohanning-org my-repo ADMIN joshjohanning"
  echo "Example: ./add-user-to-repository.sh joshjohanning-org my-repo ADMIN joshjohanning true"
  echo "Valid roles: ADMIN, MAINTAIN, WRITE, TRIAGE, READ"
  echo "skip_invite_check: true to skip checking/canceling pending invitations, defaults to false"
  exit 1
}

if [ -z "$4" ]; then
  print_usage
fi

org="$1"
repo="$2"
permission=$(echo "$3" | tr '[:lower:]' '[:upper:]')
user="$4"
skip_invite_check="${5:-false}"

case "$permission" in
  "ADMIN" | "MAINTAIN" | "WRITE" | "TRIAGE" | "READ")
    ;;
  *)
    print_usage
    ;;
esac

# Check for existing pending invitations (unless skipped)
if [ "$skip_invite_check" != "true" ]; then
  echo "Checking for existing invitations for $user..."
  pending_invitation=$(gh api "/repos/$org/$repo/invitations" --jq ".[] | select(.invitee.login == \"$user\") | .id" 2>/dev/null)

  if [ -n "$pending_invitation" ]; then
    echo "Found pending invitation (ID: $pending_invitation) for $user. Canceling it first..."
    gh api -X DELETE "/repos/$org/$repo/invitations/$pending_invitation"
    if [ $? -eq 0 ]; then
      echo "Successfully canceled pending invitation."
    else
      echo "Warning: Failed to cancel pending invitation. Proceeding anyway..."
    fi
  fi
else
  echo "Skipping invitation check as requested..."
fi

echo "Adding/inviting $user to $org/$repo with $permission permission..."
gh api -X PUT /repos/$org/$repo/collaborators/$user -f permission=$permission
