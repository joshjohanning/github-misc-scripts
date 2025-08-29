#!/bin/bash

# Gets migration information for a GitHub Enterprise Importer (GEI) migration using GraphQL API

# Usage function
usage() {
    echo "Usage: $0 <migration-id>"
    echo ""
    echo "Get migration information for a given migration ID"
    echo ""
    echo "Examples:"
    echo "  ./get-migration-info.sh RM_kgDaACQzNWUwMWIxNS0yZmRjLTRjYWQtOTUwNy00YTgwNGNhZThiMTk"
    echo ""
    echo "Notes:"
    echo "  - Migration ID is the GraphQL node ID (not the REST API migration ID)"
    echo "  - Requires using a classic Personal Access Token (ghp_*) with appropriate scopes"
    exit 1
}

# Check if migration ID is provided
if [ -z "$1" ]; then
    usage
fi

migration_id="$1"

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔍 Fetching migration information for ID: $migration_id"
echo ""

# Execute the GraphQL query
migration_info=$(gh api graphql -f id="$migration_id" -f query='
query ($id: ID!) {
  node(id: $id) {
    ... on Migration {
      id
      sourceUrl
      migrationSource {
        name
      }
      state
      failureReason
    }
  }
}')

# Check if the query was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to fetch migration information${NC}"
    echo "This could be due to:"
    echo "  - Invalid migration ID"
    echo "  - Insufficient permissions (set a class token with \`export GH_TOKEN=ghp_your_token\`)"
    exit 1
fi

# Check if migration data is null
if echo "$migration_info" | jq -e '.data.node == null' >/dev/null 2>&1; then
    echo -e "${RED}❌ Migration not found${NC}"
    echo "Migration ID '$migration_id' does not exist or you don't have access to it."
    exit 1
fi

# Extract migration details
id=$(echo "$migration_info" | jq -r '.data.node.id // "N/A"')
source_url=$(echo "$migration_info" | jq -r '.data.node.sourceUrl // "N/A"')
migration_source=$(echo "$migration_info" | jq -r '.data.node.migrationSource.name // "N/A"')
state=$(echo "$migration_info" | jq -r '.data.node.state // "N/A"')
failure_reason=$(echo "$migration_info" | jq -r '.data.node.failureReason // "N/A"')

# Display the results with formatting
echo "📊 Migration Information"
echo "======================="
echo ""
echo -e "${BLUE}🆔 Migration ID:${NC} $id"
echo -e "${BLUE}🌐 Source URL:${NC} $source_url"
echo -e "${BLUE}📍 Migration Source:${NC} $migration_source"

# Color code the state
case "$state" in
    "SUCCEEDED" | "SUCCESS")
        echo -e "${BLUE}📊 State:${NC} ${GREEN}$state${NC}"
        ;;
    "FAILED" | "FAILURE")
        echo -e "${BLUE}📊 State:${NC} ${RED}$state${NC}"
        ;;
    "IN_PROGRESS" | "PENDING")
        echo -e "${BLUE}📊 State:${NC} ${YELLOW}$state${NC}"
        ;;
    *)
        echo -e "${BLUE}📊 State:${NC} $state"
        ;;
esac

# Only show failure reason if it exists and is not "N/A"
if [ "$failure_reason" != "N/A" ] && [ "$failure_reason" != "null" ]; then
    echo -e "${BLUE}❌ Failure Reason:${NC} ${RED}$failure_reason${NC}"
fi

echo ""
echo "✅ Migration information retrieved successfully"
