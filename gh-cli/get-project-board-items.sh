#!/bin/bash

# Extract project board cards and descriptions using GraphQL
# This script works with GitHub Projects V2 (the newer project boards)
# Usage: ./get-project-board-items.sh <org> <project-number>

# This will get all issues and pull requests linked to the project board,
# it will bring in any comments but only the first 100 comments as currently constructed

if [ $# -ne 2 ]; then
    echo "Usage: $0 <org> <project-number>"
    echo "Example: ./get-project-board-items.sh my-org 123"
    echo "Example: ./get-project-board-items.sh my-org 123" > results.txt
    echo ""
    echo "Note: This script works with Projects V2 (the newer project boards)"
    echo "To find project number, check the URL: github.com/orgs/ORG/projects/NUMBER"
    exit 1
fi

org="$1"
project_number="$2"

echo "🔍 Fetching project board items for project #$project_number in $org..."
echo ""

# GraphQL query to get project items with their content and field values
response=$(gh api graphql --paginate -f org="$org" -F projectNumber="$project_number" -f query='
  query($org: String!, $projectNumber: Int!, $endCursor: String) {
    organization(login: $org) {
      projectV2(number: $projectNumber) {
        title
        id
        items(first: 100, after: $endCursor) {
          nodes {
            id
            content {
              __typename
              ... on Issue {
                title
                body
                number
                url
                repository {
                  name
                  owner {
                    login
                  }
                }
                labels(first: 10) {
                  nodes {
                    name
                  }
                }
                comments(first: 100) {
                  nodes {
                    body
                    author {
                      login
                    }
                    createdAt
                    updatedAt
                  }
                }
              }
              ... on PullRequest {
                title
                body
                number
                url
                repository {
                  name
                  owner {
                    login
                  }
                }
                comments(first: 100) {
                  nodes {
                    body
                    author {
                      login
                    }
                    createdAt
                    updatedAt
                  }
                }
              }
              ... on DraftIssue {
                title
                body
              }
            }
            fieldValues(first: 100) {
              nodes {
                ... on ProjectV2ItemFieldTextValue {
                  text
                  field {
                    ... on ProjectV2FieldCommon {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field {
                    ... on ProjectV2FieldCommon {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldIterationValue {
                  title
                  field {
                    ... on ProjectV2FieldCommon {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldDateValue {
                  date
                  field {
                    ... on ProjectV2FieldCommon {
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldNumberValue {
                  number
                  field {
                    ... on ProjectV2FieldCommon {
                      name
                    }
                  }
                }
              }
            }
          }
          pageInfo {
            endCursor
            hasNextPage
          }
        }
      }
    }
  }
' 2>&1)

# Check for errors
if [ $? -ne 0 ]; then
    if echo "$response" | grep -q "INSUFFICIENT_SCOPES"; then
        echo "❌ Error: Your GitHub token doesn't have the required permissions"
        echo ""
        echo "🔐 Required scope: 'read:project'"
        echo ""
        echo "Your token currently has these scopes:"
        # Extract current scopes from the error message
        current_scopes=$(echo "$response" | grep -o "but your token has only been granted the: \[.*\]" | sed "s/.*\[\(.*\)\].*/\1/" | tr ',' '\n' | sed "s/['\", ]//g" | grep -v "^$" | sort | uniq)
        if [ -n "$current_scopes" ]; then
            echo "$current_scopes" | sed 's/^/  • /'
        else
            echo "  • (Unable to determine current scopes)"
        fi
        echo ""
        echo "📝 To fix this issue, run:"
        echo "  gh auth refresh -h github.com -s read:project"
        echo ""
        echo "ℹ️ If using a PAT, go update the permissions to include the 'read:project' scope."
        exit 1
    elif echo "$response" | grep -q "Could not resolve to a ProjectV2"; then
        echo "❌ Error: Project #$project_number not found in organization '$org'"
        echo "Make sure:"
        echo "- The project number is correct"
        echo "- The project exists in the organization (not user-owned)"
        echo "- You have access to view the project"
        exit 1
    elif echo "$response" | grep -q "403\|Forbidden"; then
        echo "❌ Error: Access denied to project #$project_number"
        echo "Make sure you have permission to view this project"
        exit 1
    else
        echo "❌ Error fetching project data:"
        echo "$response"
        exit 1
    fi
fi

# Extract project title
project_title=$(echo "$response" | jq -r '.data.organization.projectV2.title // "Unknown Project"')
echo "📋 Project: $project_title"
echo "==============================================="
echo ""

# Process items
items=$(echo "$response" | jq -c '.data.organization.projectV2.items.nodes[]?')

if [ -z "$items" ]; then
    echo "ℹ️  No items found in this project board"
    exit 0
fi

item_count=0
echo "$items" | while IFS= read -r item; do
    ((item_count++))
    
    # Extract content details
    content_type=$(echo "$item" | jq -r '.content.__typename // "Unknown"')
    
    # If __typename is Unknown but we have content, determine type from content structure
    if [ "$content_type" = "Unknown" ]; then
        # Check if it has repository info and number - it's a GitHub Issue
        if echo "$item" | jq -e '.content.repository.name and .content.number' >/dev/null 2>&1; then
            content_type="Issue"
        # Check if it has title and body but no repository - it's a Draft Issue
        elif echo "$item" | jq -e '.content.title and (.content.repository | not)' >/dev/null 2>&1; then
            content_type="DraftIssue"
        # If content is null/empty, it's a standalone project item
        elif [ "$(echo "$item" | jq -r '.content')" = "null" ] || [ -z "$(echo "$item" | jq -r '.content.title // empty')" ]; then
            content_type="ProjectItem"
        fi
    fi
    
    # Handle different content types appropriately
    if [ "$content_type" = "ProjectItem" ]; then
        title=$(echo "$item" | jq -r '.fieldValues.nodes[] | select(.field.name == "Title") | .text // empty')
        if [ -z "$title" ]; then
            title="No title"
        fi
        # Try to get body/description from custom fields
        body=$(echo "$item" | jq -r '.fieldValues.nodes[] | select(.field.name == "Description" or .field.name == "Body") | .text // empty')
        number=""
        url=""
        repo_name=""
        repo_owner=""
    else
        title=$(echo "$item" | jq -r '.content.title // "No title"')
        body=$(echo "$item" | jq -r '.content.body // ""')
        number=$(echo "$item" | jq -r '.content.number // ""')
        url=$(echo "$item" | jq -r '.content.url // ""')
        repo_name=$(echo "$item" | jq -r '.content.repository.name // ""')
        repo_owner=$(echo "$item" | jq -r '.content.repository.owner.login // ""')
    fi
    
    # Format item header
    echo "🔖 Item #$item_count"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    case $content_type in
        "Issue")
            echo "� Type: GitHub Issue"
            echo "📍 Repository: $repo_owner/$repo_name"
            echo "🔢 Number: #$number"
            echo "🌐 URL: $url"
            ;;
        "PullRequest")
            echo "🔀 Type: Pull Request"
            echo "📍 Repository: $repo_owner/$repo_name"
            echo "🔢 Number: #$number"
            echo "🌐 URL: $url"
            ;;
        "DraftIssue")
            echo "📝 Type: Draft Issue (project-only)"
            ;;
        "ProjectItem")
            echo "🎯 Type: Standalone Project Card"
            ;;
        *)
            echo "❓ Type: $content_type"
            ;;
    esac
    
    echo "📰 Title: $title"
    
    # Show description if it exists
    if [ -n "$body" ] && [ "$body" != "null" ] && [ "$body" != "" ]; then
        echo ""
        echo "📄 Description:"
        echo "┌─────────────────────────────────────────────────"
        echo "$body" | sed 's/^/│ /'
        echo "└─────────────────────────────────────────────────"
    fi
    
    # Show labels for issues
    if [ "$content_type" = "Issue" ]; then
        labels=$(echo "$item" | jq -r '.content.labels.nodes[]?.name // empty' | tr '\n' ' ' | sed 's/[[:space:]]*$//')
        if [ -n "$labels" ]; then
            echo ""
            echo "🏷️  Labels: $labels"
        fi
    fi
    
    # Show custom field values
    field_values=$(echo "$item" | jq -c '.fieldValues.nodes[]? | select(.field.name != null and .field.name != "Title" and .field.name != "Description" and .field.name != "Body")')
    if [ -n "$field_values" ]; then
        echo ""
        echo "📊 Custom Fields:"
        echo "$field_values" | while IFS= read -r field_value; do
            field_name=$(echo "$field_value" | jq -r '.field.name')
            value=""
            
            # Extract value based on field type
            if echo "$field_value" | jq -e '.text' >/dev/null 2>&1; then
                value=$(echo "$field_value" | jq -r '.text')
            elif echo "$field_value" | jq -e '.name' >/dev/null 2>&1; then
                value=$(echo "$field_value" | jq -r '.name')
            elif echo "$field_value" | jq -e '.title' >/dev/null 2>&1; then
                value=$(echo "$field_value" | jq -r '.title')
            elif echo "$field_value" | jq -e '.date' >/dev/null 2>&1; then
                value=$(echo "$field_value" | jq -r '.date')
            elif echo "$field_value" | jq -e '.number' >/dev/null 2>&1; then
                value=$(echo "$field_value" | jq -r '.number')
            fi
            
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                echo "   • $field_name: $value"
            fi
        done
    fi
    
    # Show comments for issues and pull requests
    if [ "$content_type" = "Issue" ] || [ "$content_type" = "PullRequest" ]; then
        comments=$(echo "$item" | jq -c '.content.comments.nodes[]? // empty')
        if [ -n "$comments" ]; then
            comment_count=$(echo "$comments" | wc -l | tr -d ' ')
            echo ""
            echo "💬 Comments ($comment_count):"
            echo "$comments" | while IFS= read -r comment; do
                if [ -n "$comment" ]; then
                    author=$(echo "$comment" | jq -r '.author.login // "Unknown"')
                    created_at=$(echo "$comment" | jq -r '.createdAt // ""')
                    comment_body=$(echo "$comment" | jq -r '.body // ""')
                    
                    # Format the date
                    if [ -n "$created_at" ] && [ "$created_at" != "null" ]; then
                        created_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created_at")
                    else
                        created_date="Unknown date"
                    fi
                    
                    echo "   ┌─ 👤 $author • $created_date"
                    if [ -n "$comment_body" ] && [ "$comment_body" != "null" ]; then
                        echo "$comment_body" | sed 's/[[:space:]]*$//' | sed 's/^/   │ /'
                    else
                        echo "   │ (no content)"
                    fi
                    echo "   └────────────────────────────────────────"
                fi
            done
        fi
    fi
    
    echo ""
    echo ""
done

# Count total items
total_items=$(echo "$items" | wc -l | tr -d ' ')
echo "📊 Summary: Found $total_items items in project '$project_title'"
