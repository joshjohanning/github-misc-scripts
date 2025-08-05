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
  invitation_data=$(gh api "/repos/$org/$repo/invitations" --jq ".[] | select(.invitee.login == \"$user\") | {id: .id, expired: .expired}" 2>/dev/null)

  if [ -n "$invitation_data" ]; then
    invitation_id=$(echo "$invitation_data" | jq -r '.id')
    is_expired=$(echo "$invitation_data" | jq -r '.expired')
    
    if [ "$is_expired" = "true" ]; then
      echo "Found expired invitation (ID: $invitation_id) for $user. Canceling it..."
      gh api -X DELETE "/repos/$org/$repo/invitations/$invitation_id"
      if [ $? -eq 0 ]; then
        echo "Successfully canceled expired invitation."
      else
        echo "Warning: Failed to cancel expired invitation. Proceeding anyway..."
      fi
    else
      echo "Found active invitation (ID: $invitation_id) for $user. Leaving it as is."
      echo "Skipping new invitation since an active one already exists."
      exit 0
    fi
  fi
else
  echo "Skipping invitation check as requested..."
fi

echo "Adding/inviting $user to $org/$repo with $permission permission..."
gh api -X PUT /repos/$org/$repo/collaborators/$user -f permission=$permission
