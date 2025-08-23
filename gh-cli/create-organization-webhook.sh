#!/bin/bash

# Creates an organization webhook
# because of a weird quirk with webhooks, and webhooks with CLI token can only be managed with CLI,
# recommended to run this with PAT and not OAuth token from GH CLI

# Usage: ./create-organization-webhook.sh <org> <webhook-url> <secret> [events...]
# Example: ./create-organization-webhook.sh joshjohanning-org https://smee.io/abcdefg mySecret push issues

if [ $# -lt 3 ]; then
    echo "Usage: $0 <org> <webhook-url> <secret> [events...]"
    echo "Example: $0 joshjohanning-org https://smee.io/abcdefg mySecret push issues"
    echo ""
    echo "Default events: push"
    echo "Common events: push, issues, pull_request, release, create, delete"
    exit 1
fi

ORG="$1"
WEBHOOK_URL="$2"
SECRET="$3"
shift 3
EVENTS=("$@")

# Default to push event if no events specified
if [ ${#EVENTS[@]} -eq 0 ]; then
    EVENTS=("push")
fi

# Check token type
TOKEN_TYPE=$(gh auth status --show-token 2>&1 | grep -o "gho_[a-zA-Z0-9_]*\|ghp_[a-zA-Z0-9_]*\|github_pat_[a-zA-Z0-9_]*" | head -1)
if [[ "$TOKEN_TYPE" == gho_* ]]; then
    echo "❌  Error: You're using an OAuth token (gho_*). Due to GitHub API limitations,"
    echo "   webhooks created with OAuth tokens can only be managed via the CLI."
    echo "   Consider using a Personal Access Token (ghp_*) instead."
    exit 1
elif [[ "$TOKEN_TYPE" == ghp_* ]]; then
    echo "✅ Using Personal Access Token (ghp_*) - recommended for webhook management"
    echo ""
elif [[ "$TOKEN_TYPE" == github_pat_* ]]; then
    echo "✅ Using Fine-grained Personal Access Token (github_pat_*) - recommended for webhook management"
    echo ""
else
    echo "⚠️  Could not determine token type. Proceeding anyway..."
    echo ""
fi

# Build events array for JSON
EVENTS_JSON=$(printf '"%s",' "${EVENTS[@]}" | sed 's/,$//')

echo "Creating webhook for organization: $ORG"
echo "URL: $WEBHOOK_URL"
echo "Events: ${EVENTS[*]}"
echo ""

gh api orgs/"$ORG"/hooks --method POST --input - <<EOF
{
  "name": "web",
  "active": true,
  "events": [$EVENTS_JSON],
  "config": {
    "content_type": "json",
    "insecure_ssl": "0",
    "secret": "$SECRET",
    "url": "$WEBHOOK_URL"
  }
}
EOF
