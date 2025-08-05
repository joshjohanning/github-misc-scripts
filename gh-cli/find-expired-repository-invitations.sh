#!/bin/bash

# Find expired repository invitations across all repositories in an organization

function print_usage {
  echo "Usage: $0 <org> [action]"
  echo "Example: ./find-expired-repository-invitations.sh joshjohanning-org"
  echo "Example: ./find-expired-repository-invitations.sh joshjohanning-org cancel"
  echo ""
  echo "Actions:"
  echo "  list (default) - List all expired invitations"
  echo "  cancel         - Cancel all expired invitations"
  echo ""
  echo "Note: This requires admin access to the repositories in the organization."
  exit 1
}

if [ -z "$1" ]; then
  print_usage
fi

org="$1"
action="${2:-list}"

case "$action" in
  "list" | "cancel")
    ;;
  *)
    echo "Error: Invalid action '$action'"
    print_usage
    ;;
esac

echo "Getting repositories for organization: $org"
echo ""

# Get all repositories in the organization
repos=$(gh api --paginate "/orgs/$org/repos" --jq '.[] | select(.archived == false) | .name')

if [ -z "$repos" ]; then
  echo "No repositories found or no access to organization: $org"
  exit 1
fi

total_repos=$(echo "$repos" | wc -l)
echo "Found $total_repos active repositories"

if [ "$action" = "cancel" ]; then
  echo ""
  echo "⚠️  WARNING: This will cancel all expired invitations!"
  echo "Press Enter to continue or Ctrl+C to abort..."
  read -r
fi

echo ""

total_expired=0
total_active=0
repos_with_expired=0

while IFS= read -r repo; do
  if [ -n "$repo" ]; then
    echo "Checking repository: $org/$repo"
    
    # Get all invitations for this repository
    invitations=$(gh api "/repos/$org/$repo/invitations" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
      echo "  ❌ Error: Could not access invitations for $org/$repo (insufficient permissions)"
      echo ""
      continue
    fi
    
    # Count total invitations
    invitation_count=$(echo "$invitations" | jq 'length' 2>/dev/null || echo "0")
    
    if [ "$invitation_count" -eq 0 ]; then
      echo "  ℹ️  No pending invitations"
      echo ""
      continue
    fi
    
    # Process each invitation
    repo_expired_count=0
    repo_active_count=0
    
    echo "$invitations" | jq -c '.[]' | while read -r invitation; do
      invitation_id=$(echo "$invitation" | jq -r '.id')
      invitee_login=$(echo "$invitation" | jq -r '.invitee.login // "unknown"')
      is_expired=$(echo "$invitation" | jq -r '.expired')
      permissions=$(echo "$invitation" | jq -r '.permissions')
      created_at=$(echo "$invitation" | jq -r '.created_at')
      
      if [ "$is_expired" = "true" ]; then
        echo "  🔴 EXPIRED - ID: $invitation_id, User: $invitee_login, Permission: $permissions, Created: $created_at"
        ((repo_expired_count++))
        
        if [ "$action" = "cancel" ]; then
          echo "    🗑️  Canceling expired invitation..."
          gh api -X DELETE "/repos/$org/$repo/invitations/$invitation_id"
          if [ $? -eq 0 ]; then
            echo "    ✅ Successfully canceled invitation"
          else
            echo "    ❌ Failed to cancel invitation"
          fi
        fi
      else
        echo "  🟢 ACTIVE - ID: $invitation_id, User: $invitee_login, Permission: $permissions, Created: $created_at"
        ((repo_active_count++))
      fi
    done
    
    # Count expired and active invitations for this repo
    expired_in_repo=$(echo "$invitations" | jq '[.[] | select(.expired == true)] | length' 2>/dev/null || echo "0")
    active_in_repo=$(echo "$invitations" | jq '[.[] | select(.expired == false)] | length' 2>/dev/null || echo "0")
    
    echo "  📊 Summary: $expired_in_repo expired, $active_in_repo active"
    
    if [ "$expired_in_repo" -gt 0 ]; then
      ((repos_with_expired++))
      total_expired=$((total_expired + expired_in_repo))
    fi
    
    total_active=$((total_active + active_in_repo))
    
    echo ""
  fi
done <<< "$repos"

# Final summary
echo "=================================================="
echo "SUMMARY"
echo "=================================================="
echo "Total repositories checked: $total_repos"
echo "Repositories with expired invitations: $repos_with_expired"
echo "Total expired invitations: $total_expired"
echo "Total active invitations: $total_active"

if [ "$action" = "cancel" ] && [ "$total_expired" -gt 0 ]; then
  echo ""
  echo "✅ Expired invitations have been canceled"
elif [ "$total_expired" -eq 0 ]; then
  echo ""
  echo "🎉 No expired invitations found!"
fi

if [ "$total_expired" -gt 0 ] && [ "$action" = "list" ]; then
  echo ""
  echo "💡 To cancel all expired invitations, run:"
  echo "   $0 $org cancel"
fi
