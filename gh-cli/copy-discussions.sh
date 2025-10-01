#!/bin/bash

# Copy Discussions between repositories in different enterprises
# This script copies discussions from a source repository to a target repository
# using different GitHub tokens for authentication to support cross-enterprise copying
#
# Usage: ./copy-discussions.sh <source_org> <source_repo> <target_org> <target_repo>
# Example: ./copy-discussions.sh source-org repo1 target-org repo2
#
# Prerequisites:
# - SOURCE_TOKEN environment variable with read access to source repository discussions
# - TARGET_TOKEN environment variable with write access to target repository discussions
# - Both tokens must have the 'public_repo' or 'repo' scope
# - GitHub CLI (gh) must be installed
#
# Note: This script copies discussion content, comments, replies, and basic metadata.
# Reactions and other advanced interactions are not copied.
# Attachments (images and files) will not copy over - they need manual handling.

# TODO: Polls don't copy options
# TODO: mark as answers?
# TODO: copy closed discussions and mark as closed in target?

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
  echo "Usage: $0 <source_org> <source_repo> <target_org> <target_repo>"
  echo ""
  echo "Copy discussions from source repository to target repository"
  echo ""
  echo "Required environment variables:"
  echo "  SOURCE_TOKEN - GitHub token with read access to source repository"
  echo "  TARGET_TOKEN - GitHub token with write access to target repository"
  echo ""
  echo "Example:"
  echo "  $0 source-org repo1 target-org repo2"
  exit 1
}

# Function to log messages
log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" >&2
}

# Function to log warnings
warn() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" >&2
}

# Function to log errors
error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

# Function to handle rate limiting
rate_limit_sleep() {
  local seconds=${1:-2}
  log "Waiting ${seconds}s to avoid rate limiting..."
  sleep "$seconds"
}

# Function to handle rate limit errors with exponential backoff
handle_rate_limit_error() {
  local response="$1"
  local attempt=${2:-1}
  
  if echo "$response" | grep -q "exceeded a secondary rate limit\|rate limit"; then
    local wait_time=$((attempt * 60))  # Start with 1 minute, then 2, 3, etc.
    warn "Hit rate limit! Waiting ${wait_time} seconds before retrying (attempt $attempt)"
    sleep "$wait_time"
    return 0  # Indicates we should retry
  fi
  
  return 1  # Not a rate limit error
}

# Function to check if a command exists
check_command() {
  if ! command -v "$1" &> /dev/null; then
    error "$1 is required but not installed. Please install $1 and try again."
    exit 1
  fi
}

# Check for required dependencies
log "Checking for required dependencies..."
check_command "gh"
check_command "jq"
log "✓ All required dependencies are installed"

# Validate input parameters
if [ $# -ne 4 ]; then
  usage
fi

SOURCE_ORG="$1"
SOURCE_REPO="$2"
TARGET_ORG="$3"
TARGET_REPO="$4"

# Initialize tracking variables
missing_categories=()

# Validate required environment variables
if [ -z "$SOURCE_TOKEN" ]; then
  error "SOURCE_TOKEN environment variable is required"
  exit 1
fi

if [ -z "$TARGET_TOKEN" ]; then
  error "TARGET_TOKEN environment variable is required"
  exit 1
fi

log "Starting discussion copy process..."
log "Source: $SOURCE_ORG/$SOURCE_REPO"
log "Target: $TARGET_ORG/$TARGET_REPO"
log ""
log "⚡ This script uses conservative rate limiting to avoid GitHub API limits"
log "   If you encounter rate limit errors, the script will automatically retry"
log ""

# GraphQL query to fetch discussions from source repository
fetch_discussions_query='
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    discussions(first: 100, after: $cursor, orderBy: {field: CREATED_AT, direction: ASC}) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        id
        title
        body
        category {
          id
          name
          slug
          description
          emoji
        }
        labels(first: 100) {
          nodes {
            id
            name
            color
            description
          }
        }
        author {
          login
        }
        createdAt
        closed
        locked
        upvoteCount
        url
        number

      }
    }
  }
}'

# GraphQL query to fetch discussion categories from target repository
fetch_categories_query='
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    discussionCategories(first: 100) {
      nodes {
        id
        name
        slug
        emoji
        description
      }
    }
  }
}'

# GraphQL query to check if discussions are enabled
check_discussions_enabled_query='
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    hasDiscussionsEnabled
    discussionCategories(first: 1) {
      nodes {
        id
      }
    }
  }
}'

# GraphQL query to fetch comments for a specific discussion
fetch_discussion_comments_query='
query($discussionId: ID!) {
  node(id: $discussionId) {
    ... on Discussion {
      comments(first: 100) {
        nodes {
          id
          body
          author {
            login
          }
          createdAt
          upvoteCount
          replies(first: 50) {
            nodes {
              id
              body
              author {
                login
              }
              createdAt
              upvoteCount
            }
          }
        }
      }
    }
  }
}'

# GraphQL query to fetch labels from target repository
fetch_labels_query='
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    labels(first: 100) {
      nodes {
        id
        name
        color
        description
      }
    }
  }
}'

# GraphQL mutation to create label in target repository
create_label_mutation='
mutation($repositoryId: ID!, $name: String!, $color: String!, $description: String) {
  createLabel(input: {
    repositoryId: $repositoryId,
    name: $name,
    color: $color,
    description: $description
  }) {
    label {
      id
      name
    }
  }
}'

# GraphQL mutation to create discussion in target repository
create_discussion_mutation='
mutation($repositoryId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
  createDiscussion(input: {
    repositoryId: $repositoryId,
    categoryId: $categoryId,
    title: $title,
    body: $body
  }) {
    clientMutationId
    discussion {
      id
      title
      url
      number
    }
  }
}'

# GraphQL mutation to add labels to discussion
add_labels_to_discussion_mutation='
mutation($labelableId: ID!, $labelIds: [ID!]!) {
  addLabelsToLabelable(input: {
    labelableId: $labelableId,
    labelIds: $labelIds
  }) {
    labelable {
      labels(first: 100) {
        nodes {
          name
        }
      }
    }
  }
}'

# GraphQL mutation to add comment to discussion
add_discussion_comment_mutation='
mutation($discussionId: ID!, $body: String!) {
  addDiscussionComment(input: {
    discussionId: $discussionId,
    body: $body
  }) {
    comment {
      id
      body
      createdAt
    }
  }
}'

# GraphQL mutation to add reply to discussion comment
add_discussion_comment_reply_mutation='
mutation($discussionId: ID!, $replyToId: ID!, $body: String!) {
  addDiscussionComment(input: {
    discussionId: $discussionId,
    replyToId: $replyToId,
    body: $body
  }) {
    comment {
      id
      body
      createdAt
    }
  }
}'

# Function to get repository ID
get_repository_id() {
  local org=$1
  local repo=$2
  local token=$3
  
  local query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      id
    }
  }'
  
  GH_TOKEN="$token" gh api graphql \
    -f query="$query" \
    -f owner="$org" \
    -f name="$repo" \
    --jq '.data.repository.id'
}

# Function to fetch discussion categories from target repository
# Function to check if discussions are enabled in target repository
check_discussions_enabled() {
  log "Checking if discussions are enabled in target repository..."
  
  rate_limit_sleep 4
  
  local response
  response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql \
    -f query="$check_discussions_enabled_query" \
    -f owner="$TARGET_ORG" \
    -f name="$TARGET_REPO" 2>&1)
  
  if [ $? -ne 0 ]; then
    error "Failed to check discussions status: $response"
    return 1
  fi
  
  local has_discussions_enabled
  has_discussions_enabled=$(echo "$response" | jq -r '.data.repository.hasDiscussionsEnabled // false')
  
  if [ "$has_discussions_enabled" != "true" ]; then
    error "Discussions are not enabled in the target repository: $TARGET_ORG/$TARGET_REPO"
    error "Please enable discussions in the repository settings before running this script."
    return 1
  fi
  
  log "✓ Discussions are enabled in target repository"
  return 0
}

# Function to fetch available categories from target repository
fetch_target_categories() {
  log "Fetching available categories from target repository..."
  
  rate_limit_sleep 4
  
  local response
  response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql \
    -f query="$fetch_categories_query" \
    -f owner="$TARGET_ORG" \
    -f name="$TARGET_REPO" 2>&1)
  
  if [ $? -ne 0 ]; then
    error "Failed to fetch categories: $response"
    return 1
  fi
  
  # Check for GraphQL errors
  if echo "$response" | jq -e '.errors // empty' > /dev/null 2>&1; then
    error "GraphQL error in fetch categories: $(echo "$response" | jq -r '.errors[0].message // "Unknown error"')"
    return 1
  fi
  
  target_categories=$(echo "$response" | jq -c '.data.repository.discussionCategories.nodes[]?' 2>/dev/null)
  
  if [ -z "$target_categories" ]; then
    warn "No discussion categories found in target repository"
  else
    local category_count
    category_count=$(echo "$target_categories" | wc -l | tr -d ' ')
    log "Found $category_count categories in target repository"
  fi
}

# Function to find matching category ID by name or slug
find_category_id() {
  local source_category_name="$1"
  local source_category_slug="$2"
  
  echo "$target_categories" | jq -r --arg name "$source_category_name" --arg slug "$source_category_slug" '
    select(.name == $name or .slug == $slug) | .id
  ' | head -1
}

# Function to create discussion category if it doesn't exist
create_or_get_category_id() {
  local category_name="$1"
  local category_slug="$2"
  local category_description="$3"
  local category_emoji="$4"
  
  # First try to find existing category
  
  # Validate target_categories JSON
  if ! echo "$target_categories" | jq . > /dev/null 2>&1; then
    error "target_categories contains invalid JSON:"
    error "$target_categories"
    return 1
  fi
  
  local existing_id
  existing_id=$(echo "$target_categories" | jq -r --arg name "$category_name" --arg slug "$category_slug" '
    select(.name == $name or .slug == $slug) | .id
  ' | head -1)
  
  if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
    echo "$existing_id"
    return 0
  fi
  
  # Category doesn't exist - GitHub doesn't support creating discussion categories via API
  warn "Category '$category_name' ($category_slug) not found in target repository"
  
  # Track missing category for summary
  local found=false
  for existing_cat in "${missing_categories[@]}"; do
    if [ "$existing_cat" = "$category_name" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    missing_categories+=("$category_name")
  fi
  
  # Try to find "General" category as fallback
  local general_id
  general_id=$(echo "$target_categories" | jq -r '
    select(.name == "General" or .slug == "general") | .id
  ' | head -1)
  
  if [ -n "$general_id" ] && [ "$general_id" != "null" ]; then
    warn "Using 'General' category as fallback for '$category_name'"
    echo "$general_id"
    return 0
  fi
  
  # If no General category, use the first available category
  local first_category_id
  first_category_id=$(echo "$target_categories" | jq -r '.id' | head -1)
  
  if [ -n "$first_category_id" ] && [ "$first_category_id" != "null" ]; then
    local first_category_name
    first_category_name=$(echo "$target_categories" | jq -r '.name' | head -1)
    warn "Using '$first_category_name' category as fallback for '$category_name'"
    echo "$first_category_id"
    return 0
  fi
  
  error "No available categories found in target repository to use as fallback"
  return 1
}

# Function to fetch labels from target repository
fetch_target_labels() {
  log "Fetching labels from target repository..."
  
  local max_retries=3
  local attempt=1
  
  while [ $attempt -le $max_retries ]; do
    rate_limit_sleep 3  # Increased default wait time
    
    local response
    response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql \
      -f query="$fetch_labels_query" \
      -f owner="$TARGET_ORG" \
      -f name="$TARGET_REPO" 2>&1)
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
      # Success, process the response
      break
    else
      # Check if it's a rate limit error
      if handle_rate_limit_error "$response" "$attempt"; then
        attempt=$((attempt + 1))
        log "Retrying labels fetch (attempt $attempt/$max_retries)..."
        continue
      else
        error "Failed to fetch labels: $response"
        return 1
      fi
    fi
  done
  
  if [ $attempt -gt $max_retries ]; then
    error "Failed to fetch labels after $max_retries attempts due to rate limiting"
    return 1
  fi
  
  # Check if response is valid JSON
  if ! echo "$response" | jq . > /dev/null 2>&1; then
    error "Invalid JSON response from labels API: $response"
    return 1
  fi
  
  # Check for GraphQL errors
  if echo "$response" | jq -e '.errors // empty' > /dev/null 2>&1; then
    error "GraphQL error in fetch labels: $(echo "$response" | jq -r '.errors[0].message // "Unknown error"')"
    return 1
  fi
  
  echo "$response" | jq -c '.data.repository.labels.nodes[]?' 2>/dev/null
}

# Function to fetch comments for a specific discussion
fetch_discussion_comments() {
  local discussion_id="$1"
  
  log "Fetching comments for discussion $discussion_id..."
  
  rate_limit_sleep 2
  
  local response
  response=$(GH_TOKEN="$SOURCE_TOKEN" gh api graphql \
    -f query="$fetch_discussion_comments_query" \
    -f discussionId="$discussion_id" 2>&1)
  
  if [ $? -ne 0 ]; then
    error "Failed to fetch comments for discussion $discussion_id: $response"
    return 1
  fi
  
  # Check for GraphQL errors
  if echo "$response" | jq -e '.errors // empty' > /dev/null 2>&1; then
    error "GraphQL error in fetch comments: $(echo "$response" | jq -r '.errors[0].message // "Unknown error"')"
    return 1
  fi
  
  # Extract comments
  local comments
  comments=$(echo "$response" | jq -c '.data.node.comments.nodes // []' 2>/dev/null)
  
  if [ -z "$comments" ]; then
    log "No comments found for discussion"
    echo "[]"
  else
    echo "$comments"
  fi
}

# Function to find matching label ID by name
find_label_id() {
  local label_name="$1"
  
  echo "$target_labels" | jq -r --arg name "$label_name" '
    select(.name == $name) | .id
  ' | head -1
}

# Function to create label if it doesn't exist
create_or_get_label_id() {
  local label_name="$1"
  local label_color="$2"
  local label_description="$3"
  
  # First try to find existing label
  local existing_id
  existing_id=$(find_label_id "$label_name")
  
  if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
    echo "$existing_id"
    return 0
  fi
  
  # Label doesn't exist, create it
  log "Creating new label: '$label_name'"
  
  rate_limit_sleep 3
  
  local response
  response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql \
    -f query="$create_label_mutation" \
    -f repositoryId="$target_repo_id" \
    -f name="$label_name" \
    -f color="$label_color" \
    -f description="$label_description" 2>&1)
  
  if [ $? -eq 0 ]; then
    local new_label_id
    new_label_id=$(echo "$response" | jq -r '.data.createLabel.label.id')
    
    if [ -n "$new_label_id" ] && [ "$new_label_id" != "null" ]; then
      log "✓ Created label '$label_name' with ID: $new_label_id"
      
      # Update our local cache of target labels (if target_labels is an array)
      if echo "$target_labels" | jq -e 'type == "array"' >/dev/null 2>&1; then
        target_labels=$(echo "$target_labels" | jq --arg id "$new_label_id" --arg name "$label_name" --arg color "$label_color" --arg desc "$label_description" '. + [{id: $id, name: $name, color: $color, description: $desc}]')
      else
        # If target_labels is not an array, convert it
        target_labels=$(jq -n --arg id "$new_label_id" --arg name "$label_name" --arg color "$label_color" --arg desc "$label_description" '[{id: $id, name: $name, color: $color, description: $desc}]')
      fi
      
      echo "$new_label_id"
      return 0
    fi
  fi
  
  error "Failed to create label '$label_name': $response"
  return 1
}

# Function to add labels to a discussion
add_labels_to_discussion() {
  local discussion_id="$1"
  shift
  local label_ids=("$@")
  
  if [ ${#label_ids[@]} -eq 0 ]; then
    return 0
  fi
  
  # Convert array to JSON array format for GraphQL
  local label_ids_json
  label_ids_json=$(printf '%s\n' "${label_ids[@]}" | jq -R . | jq -s . | jq -c .)
  
  log "Adding ${#label_ids[@]} labels to discussion"
  log "Discussion ID: $discussion_id"
  log "Label IDs (compact JSON): $label_ids_json"
  
  rate_limit_sleep 2
  
  # Construct the full GraphQL request with variables
  local graphql_request
  graphql_request=$(jq -n \
    --arg query "$add_labels_to_discussion_mutation" \
    --arg labelableId "$discussion_id" \
    --argjson labelIds "$label_ids_json" \
    '{
      query: $query,
      variables: {
        labelableId: $labelableId,
        labelIds: $labelIds
      }
    }')
  
  log "GraphQL request: $graphql_request"
  
  local response
  response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql --input - <<< "$graphql_request" 2>&1)
  
  local api_exit_code=$?
  
  log "GraphQL API exit code: $api_exit_code"
  log "GraphQL API response: $response"
  
  if [ $api_exit_code -eq 0 ]; then
    # Check if there are any errors in the response
    local errors
    errors=$(echo "$response" | jq -r '.errors // empty | .[] | .message' 2>/dev/null)
    if [ -n "$errors" ]; then
      error "GraphQL errors in response: $errors"
      return 1
    fi
    
    log "✓ Successfully added labels to discussion"
    return 0
  else
    error "Failed to add labels to discussion (exit code: $api_exit_code): $response"
    return 1
  fi
}

# Function to add comment to discussion
add_discussion_comment() {
  local discussion_id="$1"
  local comment_body="$2"
  local original_author="$3"
  local original_created="$4"
  
  # Add metadata to comment body with collapsible section
  local enhanced_body="$comment_body"$'\n\n'"---"$'\n\n'"<details>"$'\n'"<summary>Original comment details</summary>"$'\n\n'"**Original author:** @$original_author"$'\n'"**Created:** $original_created"$'\n\n'"</details>"
  
  log "Adding comment to discussion"
  
  rate_limit_sleep 2
  
  local response
  response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql \
    -f query="$add_discussion_comment_mutation" \
    -f discussionId="$discussion_id" \
    -f body="$enhanced_body" 2>&1)
  
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    local comment_id
    comment_id=$(echo "$response" | jq -r '.data.addDiscussionComment.comment.id // empty')
    
    if [ -n "$comment_id" ] && [ "$comment_id" != "null" ]; then
      log "✓ Added comment with ID: $comment_id"
      echo "$comment_id"
      return 0
    else
      error "Failed to extract comment ID from response: $response"
      return 1
    fi
  else
    error "Failed to add comment: $response"
    return 1
  fi
}

# Function to add reply to discussion comment
add_discussion_comment_reply() {
  local discussion_id="$1"
  local parent_comment_id="$2"
  local reply_body="$3"
  local original_author="$4"
  local original_created="$5"
  
  # Add metadata to reply body with collapsible section
  local enhanced_body="$reply_body"$'\n\n'"---"$'\n\n'"<details>"$'\n'"<summary>Original reply details</summary>"$'\n\n'"**Original author:** @$original_author"$'\n'"**Created:** $original_created"$'\n\n'"</details>"
  
  log "Adding reply to comment $parent_comment_id"
  
  rate_limit_sleep 2
  
  local response
  response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql \
    -f query="$add_discussion_comment_reply_mutation" \
    -f discussionId="$discussion_id" \
    -f replyToId="$parent_comment_id" \
    -f body="$enhanced_body" 2>&1)
  
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    local reply_id
    reply_id=$(echo "$response" | jq -r '.data.addDiscussionComment.comment.id // empty')
    
    if [ -n "$reply_id" ] && [ "$reply_id" != "null" ]; then
      log "✓ Added reply with ID: $reply_id"
      echo "$reply_id"
      return 0
    else
      error "Failed to extract reply ID from response: $response"
      return 1
    fi
  else
    error "Failed to add reply: $response"
    return 1
  fi
}

# Function to copy discussion comments
copy_discussion_comments() {
  local discussion_id="$1"
  local comments_json="$2"
  
  if [ -z "$comments_json" ] || [ "$comments_json" = "null" ]; then
    log "No comments to copy for this discussion"
    return 0
  fi
  
  local comment_count
  comment_count=$(echo "$comments_json" | jq -r 'length // 0')
  
  if [ "$comment_count" -eq 0 ]; then
    log "No comments to copy for this discussion"
    return 0
  fi
  
  log "Copying $comment_count comments..."
  total_comments=$((total_comments + comment_count))
  
  local comment_index=0
  while [ $comment_index -lt "$comment_count" ]; do
    local comment
    comment=$(echo "$comments_json" | jq -r ".[$comment_index]")
    
    if [ "$comment" != "null" ]; then
      local comment_body author created_at replies
      comment_body=$(echo "$comment" | jq -r '.body // ""')
      author=$(echo "$comment" | jq -r '.author.login // "unknown"')
      created_at=$(echo "$comment" | jq -r '.createdAt // ""')
      replies=$(echo "$comment" | jq -c '.replies.nodes // []')
      
      if [ -n "$comment_body" ]; then
        log "Copying comment by @$author"
        
        # Add the comment
        set +e  # Don't exit on error
        local new_comment_id
        new_comment_id=$(add_discussion_comment "$discussion_id" "$comment_body" "$author" "$created_at")
        local comment_result=$?
        set -e
        
        if [ $comment_result -eq 0 ] && [ -n "$new_comment_id" ]; then
          copied_comments=$((copied_comments + 1))
          # Copy replies if any exist
          local reply_count
          reply_count=$(echo "$replies" | jq -r 'length // 0')
          
          if [ "$reply_count" -gt 0 ]; then
            log "Copying $reply_count replies to comment..."
            
            local reply_index=0
            while [ $reply_index -lt "$reply_count" ]; do
              local reply
              reply=$(echo "$replies" | jq -r ".[$reply_index]")
              
              if [ "$reply" != "null" ]; then
                local reply_body reply_author reply_created
                reply_body=$(echo "$reply" | jq -r '.body // ""')
                reply_author=$(echo "$reply" | jq -r '.author.login // "unknown"')
                reply_created=$(echo "$reply" | jq -r '.createdAt // ""')
                
                if [ -n "$reply_body" ]; then
                  log "Copying reply by @$reply_author"
                  
                  set +e
                  add_discussion_comment_reply "$discussion_id" "$new_comment_id" "$reply_body" "$reply_author" "$reply_created" >/dev/null
                  set -e
                fi
              fi
              
              reply_index=$((reply_index + 1))
            done
          fi
        else
          warn "Failed to copy comment by @$author, skipping replies"
        fi
      fi
    fi
    
    comment_index=$((comment_index + 1))
  done
  
  log "✓ Finished copying comments"
}

# Function to create discussion
create_discussion() {
  local repo_id="$1"
  local category_id="$2"
  local title="$3"
  local body="$4"
  local source_url="$5"
  local source_author="$6"
  local source_created="$7"
  
  # Add metadata to body with collapsible section
  local enhanced_body="$body"$'\n\n'"---"$'\n\n'"<details>"$'\n'"<summary>Original discussion details</summary>"$'\n\n'"**Original author:** @$source_author"$'\n'"**Created:** $source_created"$'\n'"**Source:** $source_url"$'\n\n'"</details>"
  
  log "Creating discussion: '$title'"
  
  rate_limit_sleep 3
  
  local response
  response=$(GH_TOKEN="$TARGET_TOKEN" gh api graphql \
    -f query="$create_discussion_mutation" \
    -f repositoryId="$repo_id" \
    -f categoryId="$category_id" \
    -f title="$title" \
    -f body="$enhanced_body" 2>&1)
  
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    echo "$response"
    return 0
  else
    error "Failed to create discussion: $response"
    return $exit_code
  fi
}

# Get source repository ID to verify access
log "Verifying access to source repository..."
source_repo_id=$(get_repository_id "$SOURCE_ORG" "$SOURCE_REPO" "$SOURCE_TOKEN")
if [ -z "$source_repo_id" ]; then
  error "Failed to get source repository ID. Check if repository exists and SOURCE_TOKEN has access."
  exit 1
fi
log "Source repository ID: $source_repo_id"

# Check if discussions are enabled in source repository
log "Checking if discussions are enabled in source repository..."
rate_limit_sleep 2

source_discussions_check=$(GH_TOKEN="$SOURCE_TOKEN" gh api graphql \
  -f query="$check_discussions_enabled_query" \
  -f owner="$SOURCE_ORG" \
  -f name="$SOURCE_REPO" 2>&1)

if [ $? -ne 0 ]; then
  error "Failed to check discussions status in source repository: $source_discussions_check"
  exit 1
fi

source_has_discussions=$(echo "$source_discussions_check" | jq -r '.data.repository.hasDiscussionsEnabled // false')
if [ "$source_has_discussions" != "true" ]; then
  error "Discussions are not enabled in the source repository: $SOURCE_ORG/$SOURCE_REPO"
  exit 1
fi
log "✓ Discussions are enabled in source repository"

# Get target repository ID
log "Getting target repository ID..."
target_repo_id=$(get_repository_id "$TARGET_ORG" "$TARGET_REPO" "$TARGET_TOKEN")
if [ -z "$target_repo_id" ]; then
  error "Failed to get target repository ID. Check if repository exists and token has access."
  exit 1
fi
log "Target repository ID: $target_repo_id"

# Check if discussions are enabled in target repository
if ! check_discussions_enabled; then
  exit 1
fi

# Fetch target repository categories
if ! fetch_target_categories; then
  exit 1
fi

if [ -z "$target_categories" ]; then
  error "Failed to fetch discussion categories from target repository"
  exit 1
fi

log "Available categories in target repository:"
echo "$target_categories" | jq -r '"  " + .name + " (" + .slug + ")"'

# Fetch target repository labels
target_labels=$(fetch_target_labels)
if [ $? -ne 0 ] || [ -z "$target_labels" ]; then
  warn "Failed to fetch labels or no labels found in target repository"
  target_labels="[]"
  log "Available labels in target repository: 0 labels"
else
  # Count labels properly
  label_count=$(echo "$target_labels" | jq -s 'length' 2>/dev/null || echo "0")
  log "Available labels in target repository: $label_count labels"
fi

# Initialize counters
total_discussions=0
created_discussions=0
skipped_discussions=0
total_comments=0
copied_comments=0

# Function to process discussions page
process_discussions_page() {
  local cursor="$1"
  
  # Build cursor parameter
  local cursor_param=""
  if [ -n "$cursor" ]; then
    cursor_param="-f cursor=$cursor"
  fi
  
  log "Fetching discussions page (cursor: ${cursor:-"null"})..."
  
  rate_limit_sleep 3
  
  # Fetch discussions from source repository
  log "Executing GraphQL query with parameters:"
  log "  owner: $SOURCE_ORG"
  log "  name: $SOURCE_REPO"
  log "  cursor: ${cursor:-"null"}"
  
  local response
  response=$(GH_TOKEN="$SOURCE_TOKEN" gh api graphql \
    -f query="$fetch_discussions_query" \
    -f owner="$SOURCE_ORG" \
    -f name="$SOURCE_REPO" \
    $cursor_param 2>&1)
  
  local api_exit_code=$?
  log "API call exit code: $api_exit_code"
  log "Response length: ${#response} characters"
  log "First 200 chars of response: ${response:0:200}"
  
  # Debug: Show what we got back
  if ! echo "$response" | jq . > /dev/null 2>&1; then
    error "Invalid JSON response from source discussions API!"
    error "Full response:"
    error "$response"
    error "---"
    error "API exit code was: $api_exit_code"
    error "This could be:"
    error "  1. Authentication issue with SOURCE_TOKEN"
    error "  2. Repository access permissions"
    error "  3. Repository doesn't exist or discussions disabled"
    error "  4. Network/API connectivity issue"
    error "  5. GraphQL query syntax error"
    return 1
  fi
  
  # Check for GraphQL errors
  if echo "$response" | jq -e '.errors // empty' > /dev/null 2>&1; then
    error "GraphQL error in fetch discussions: $(echo "$response" | jq -r '.errors[0].message // "Unknown error"')"
    return 1
  fi
  
  local discussions
  discussions=$(echo "$response" | jq -c '.data.repository.discussions.nodes[]' 2>&1)
  local jq_extract_exit_code=$?
  
  log "JQ extraction exit code: $jq_extract_exit_code"
  log "Extracted discussions from response"
  log "Discussions data length: ${#discussions} characters"
  
  if [ $jq_extract_exit_code -ne 0 ]; then
    error "Failed to extract discussions with jq:"
    error "$discussions"
    return 1
  fi
  
  if [ -z "$discussions" ]; then
    log "No discussions found on this page"
    log "Checking response structure:"
    echo "$response" | jq '.data.repository.discussions' 2>/dev/null || log "Failed to parse discussions structure"
    return 1
  fi
  
  local discussion_count
  discussion_count=$(echo "$discussions" | wc -l | tr -d ' ')
  log "Found $discussion_count discussions to process on this page"
  
  # Process each discussion
  local discussion_counter=0
  log "Starting to iterate through discussions..."
  log "About to process discussions with while loop"
  
  while IFS= read -r discussion; do
    discussion_counter=$((discussion_counter + 1))
    log "=== DISCUSSION $discussion_counter ==="
    
    if [ -z "$discussion" ]; then
      log "Skipping empty discussion entry at position $discussion_counter"
      continue
    fi
    
    total_discussions=$((total_discussions + 1))
    
    log "Processing discussion $discussion_counter of this page (total: $total_discussions)"
    
    # Show the COMPLETE JSON for debugging
    log "=== COMPLETE DISCUSSION JSON ==="
    printf '%s\n' "$discussion"
    log "=== END COMPLETE JSON ==="
    
    # Debug: Show what we're trying to parse
    log "Discussion data length: ${#discussion} characters"
    log "Discussion data (first 200 chars): ${discussion:0:200}"
    log "Discussion data (last 200 chars): ${discussion: -200}"
    
    # Try to identify the exact jq error
    local jq_error
    jq_error=$(echo "$discussion" | jq . 2>&1)
    local jq_exit_code=$?
    
    if [ $jq_exit_code -ne 0 ]; then
      error "JSON parsing failed with exit code: $jq_exit_code"
      error "JQ error message: $jq_error"
      error "Full discussion data:"
      error "$discussion"
      error "---"
      error "Hexdump of first 50 bytes:"
      echo "$discussion" | head -c 50 | hexdump -C
      error "---"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    log "✓ Discussion JSON is valid"
    
    # Extract discussion details with error handling
    local title body category_name category_slug category_description category_emoji author created_at source_url number
    
    log "Extracting title..."
    title=$(echo "$discussion" | jq -r '.title' 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to extract title: $title"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    log "Title: $title"
    
    log "Extracting body..."
    body=$(echo "$discussion" | jq -r '.body // ""' 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to extract body: $body"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    log "Extracting category details..."
    category_name=$(echo "$discussion" | jq -r '.category.name' 2>&1)
    category_slug=$(echo "$discussion" | jq -r '.category.slug' 2>&1)
    category_description=$(echo "$discussion" | jq -r '.category.description // ""' 2>&1)
    category_emoji=$(echo "$discussion" | jq -r '.category.emoji // ":speech_balloon:"' 2>&1)
    
    log "Extracting author..."
    author=$(echo "$discussion" | jq -r '.author.login // "unknown"' 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to extract author: $author"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    log "Extracting createdAt..."
    created_at=$(echo "$discussion" | jq -r '.createdAt' 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to extract createdAt: $created_at"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    log "Extracting url..."
    source_url=$(echo "$discussion" | jq -r '.url' 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to extract url: $source_url"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    log "Extracting number..."
    number=$(echo "$discussion" | jq -r '.number' 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to extract number: $number"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    # Get or create category in target repository
    log "Getting/creating category: '$category_name' ($category_slug)"
    local target_category_id
    set +e  # Temporarily disable exit on error
    target_category_id=$(create_or_get_category_id "$category_name" "$category_slug" "$category_description" "$category_emoji")
    local category_exit_code=$?
    set -e  # Re-enable exit on error
    
    if [ $category_exit_code -ne 0 ]; then
      error "create_or_get_category_id failed with exit code: $category_exit_code"
      error "Output was: $target_category_id"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    if [ -z "$target_category_id" ] || [ "$target_category_id" == "null" ]; then
      error "Failed to get or create category '$category_name' ($category_slug). Skipping discussion #$number: '$title'"
      skipped_discussions=$((skipped_discussions + 1))
      continue
    fi
    
    # Create the discussion
    local new_discussion_id new_discussion_response
    new_discussion_response=$(create_discussion "$target_repo_id" "$target_category_id" "$title" "$body" "$source_url" "$author" "$created_at")
    
    if [ $? -eq 0 ]; then
      # Extract the discussion ID from the response
      new_discussion_id=$(echo "$new_discussion_response" | jq -r '.data.createDiscussion.discussion.id // empty')
      
      if [ -n "$new_discussion_id" ]; then
        created_discussions=$((created_discussions + 1))
        log "✓ Created discussion #$number: '$title'"
        
        # Process labels if any
        local labels
        labels=$(echo "$discussion" | jq -c '.labels.nodes[]?')
        
        if [ -n "$labels" ]; then
          local label_ids=()
          
          # Process each label
          while IFS= read -r label; do
            if [ -n "$label" ]; then
              local label_name label_color label_description label_id
              label_name=$(echo "$label" | jq -r '.name')
              label_color=$(echo "$label" | jq -r '.color')
              label_description=$(echo "$label" | jq -r '.description // ""')
              
              # Get or create label
              log "Processing label: '$label_name' (color: $label_color)"
              set +e  # Temporarily disable exit on error
              label_id=$(create_or_get_label_id "$label_name" "$label_color" "$label_description")
              local label_exit_code=$?
              set -e  # Re-enable exit on error
              log "Label ID result: '$label_id' (exit code: $label_exit_code)"
              
              if [ $label_exit_code -eq 0 ] && [ -n "$label_id" ] && [ "$label_id" != "null" ]; then
                label_ids+=("$label_id")
                log "Added label ID to array: $label_id"
              else
                log "Skipping invalid label ID: '$label_id' (exit code: $label_exit_code)"
              fi
            fi
          done <<< "$labels"
          
          log "Finished processing labels. Total label IDs collected: ${#label_ids[@]}"
          
          # Add labels to the discussion if we have any
          if [ ${#label_ids[@]} -gt 0 ]; then
            if add_labels_to_discussion "$new_discussion_id" "${label_ids[@]}"; then
              log "Completed adding labels to discussion"
            else
              error "Failed to add labels to discussion, but continuing..."
            fi
          else
            log "No valid labels to add to discussion"
          fi
        fi
        
        # Copy discussion comments (always run regardless of labels)
        log "Processing comments for discussion..."
        local source_discussion_id
        source_discussion_id=$(echo "$discussion" | jq -r '.id')
        
        if [ -n "$source_discussion_id" ] && [ "$source_discussion_id" != "null" ]; then
          set +e  # Don't exit on error for comment fetching
          local comments
          comments=$(fetch_discussion_comments "$source_discussion_id")
          local fetch_result=$?
          set -e
          
          if [ $fetch_result -eq 0 ] && [ -n "$comments" ] && [ "$comments" != "null" ] && [ "$comments" != "[]" ]; then
            copy_discussion_comments "$new_discussion_id" "$comments"
          else
            log "No comments to copy for this discussion"
          fi
        else
          warn "Could not extract source discussion ID for comment fetching"
        fi
      else
        warn "Discussion created but couldn't extract ID from response"
        created_discussions=$((created_discussions + 1))
      fi
    else
      error "Failed to create discussion #$number: '$title'"
      skipped_discussions=$((skipped_discussions + 1))
    fi
    
    log "✅ Finished processing discussion #$number: '$title'"
    
    # Delay between discussions to avoid rate limiting
    sleep 5
    
  done <<< "$discussions"
  
  # Check if there are more pages
  local has_next_page next_cursor
  has_next_page=$(echo "$response" | jq -r '.data.repository.discussions.pageInfo.hasNextPage')
  next_cursor=$(echo "$response" | jq -r '.data.repository.discussions.pageInfo.endCursor')
  
  log "Pagination info:"
  log "  hasNextPage: $has_next_page"
  log "  endCursor: ${next_cursor:-"null"}"
  
  if [ "$has_next_page" = "true" ]; then
    log "Processing next page with cursor: $next_cursor"
    process_discussions_page "$next_cursor"
  else
    log "No more pages to process"
  fi
}

# Test discussions access first
log "Testing discussions access..."
rate_limit_sleep 2

test_discussions_query='
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    discussions(first: 1) {
      totalCount
      nodes {
        title
      }
    }
  }
}'

test_response=$(GH_TOKEN="$SOURCE_TOKEN" gh api graphql \
  -f query="$test_discussions_query" \
  -f owner="$SOURCE_ORG" \
  -f name="$SOURCE_REPO" 2>&1)

if ! echo "$test_response" | jq . > /dev/null 2>&1; then
  error "Failed to test discussions access:"
  error "Raw response: $test_response"
  exit 1
fi

discussion_count=$(echo "$test_response" | jq -r '.data.repository.discussions.totalCount // 0')
log "Found $discussion_count total discussions in source repository"

if [ "$discussion_count" -eq 0 ]; then
  log "No discussions found in source repository. Nothing to copy."
  exit 0
fi

# Start processing discussions
log "Starting to fetch and copy discussions..."
process_discussions_page ""

# Summary
log "Discussion copy completed!"
log "Total discussions found: $total_discussions"
log "Discussions created: $created_discussions"
log "Discussions skipped: $skipped_discussions"
log "Total comments found: $total_comments"
log "Comments copied: $copied_comments"

if [ ${#missing_categories[@]} -gt 0 ]; then
  warn "The following categories were missing and need to be created manually:"
  for missing_cat in "${missing_categories[@]}"; do
    warn "  - $missing_cat"
  done
  warn ""
  warn "To create categories manually:"
  warn "1. Go to https://github.com/$TARGET_ORG/$TARGET_REPO/discussions"
  warn "2. Click 'New discussion'"
  warn "3. Look for category management options"
  warn "4. Create the missing categories with appropriate names and descriptions"
fi

if [ $skipped_discussions -gt 0 ]; then
  warn "Some discussions were skipped. Please check the categories in the target repository."
fi

log "All done! ✨"