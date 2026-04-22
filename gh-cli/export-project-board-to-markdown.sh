#!/bin/bash

# Export a GitHub Projects V2 board to a clean Markdown file suitable for sharing
# (e.g. as a customer-facing engagement deliverable).
#
# Differences from get-project-board-items.sh:
# - Outputs valid Markdown (headings, links, tables) instead of decorated terminal text
# - Issue / PR bodies and comments are emitted as raw Markdown so embedded
#   headings, lists, task lists, code fences, and blockquotes render correctly
# - Generates a clickable Table of Contents
# - Writes to a file (default: slugified project title, e.g. <project-title-slug>.md) instead of stdout
#
# Usage: ./export-project-board-to-markdown.sh <org> <project-number> [output-file]
# Example: ./export-project-board-to-markdown.sh my-org 123
# Example: ./export-project-board-to-markdown.sh my-org 123 smbc-export.md

set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <org> <project-number> [output-file]"
    echo "Example: ./export-project-board-to-markdown.sh my-org 123"
    echo "Example: ./export-project-board-to-markdown.sh my-org 123 smbc-export.md"
    echo ""
    echo "Note: This script works with Projects V2 (the newer project boards)"
    echo "To find project number, check the URL: github.com/orgs/ORG/projects/NUMBER"
    exit 1
fi

org="$1"
project_number="$2"
output_file="${3:-}"

echo "🔍 Fetching project board items for project #$project_number in $org..." >&2

response=$(gh api graphql --paginate -f org="$org" -F projectNumber="$project_number" -f query='
  query($org: String!, $projectNumber: Int!, $endCursor: String) {
    organization(login: $org) {
      projectV2(number: $projectNumber) {
        title
        url
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
                state
                createdAt
                author { login }
                repository { name owner { login } }
                labels(first: 20) { nodes { name } }
                assignees(first: 10) { nodes { login } }
                comments(first: 100) {
                  nodes {
                    body
                    author { login }
                    createdAt
                  }
                }
              }
              ... on PullRequest {
                title
                body
                number
                url
                state
                merged
                createdAt
                author { login }
                repository { name owner { login } }
                labels(first: 20) { nodes { name } }
                assignees(first: 10) { nodes { login } }
                comments(first: 100) {
                  nodes {
                    body
                    author { login }
                    createdAt
                  }
                }
              }
              ... on DraftIssue {
                title
                body
                createdAt
                creator { login }
              }
            }
            fieldValues(first: 100) {
              nodes {
                ... on ProjectV2ItemFieldTextValue {
                  text
                  field { ... on ProjectV2FieldCommon { name } }
                }
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field { ... on ProjectV2FieldCommon { name } }
                }
                ... on ProjectV2ItemFieldIterationValue {
                  title
                  field { ... on ProjectV2FieldCommon { name } }
                }
                ... on ProjectV2ItemFieldDateValue {
                  date
                  field { ... on ProjectV2FieldCommon { name } }
                }
                ... on ProjectV2ItemFieldNumberValue {
                  number
                  field { ... on ProjectV2FieldCommon { name } }
                }
              }
            }
          }
          pageInfo { endCursor hasNextPage }
        }
      }
    }
  }
' 2>&1) || {
    if echo "$response" | grep -q "INSUFFICIENT_SCOPES"; then
        echo "❌ Error: Your GitHub token doesn't have the required permissions" >&2
        echo "🔐 Required scope: 'read:project'" >&2
        echo "Run: gh auth refresh -h github.com -s read:project" >&2
    elif echo "$response" | grep -q "Could not resolve to a ProjectV2"; then
        echo "❌ Error: Project #$project_number not found in organization '$org'" >&2
    else
        echo "❌ Error fetching project data:" >&2
        echo "$response" >&2
    fi
    exit 1
}

project_title=$(echo "$response" | jq -r '.data.organization.projectV2.title // "Unknown Project"' | head -n 1)
project_url=$(echo "$response" | jq -r '.data.organization.projectV2.url // ""' | head -n 1)

# Default output filename: slugified project title
if [ -z "$output_file" ]; then
    slug=$(echo "$project_title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
    output_file="${slug:-project-export}.md"
fi

echo "📝 Writing Markdown to: $output_file" >&2

# Collect all items across paginated responses into a single JSON array
items_json=$(echo "$response" | jq -s '[.[] | .data.organization.projectV2.items.nodes[]?]')

total=$(echo "$items_json" | jq 'length')

{
    echo "# $project_title"
    echo ""
    if [ -n "$project_url" ] && [ "$project_url" != "null" ]; then
        echo "**Project board:** [$project_url]($project_url)"
        echo ""
    fi
    echo "**Generated:** $(date -u +"%Y-%m-%d %H:%M UTC")  "
    echo "**Total items:** $total"

    # Status breakdown (from project Status field)
    status_summary=$(echo "$items_json" | jq -r '
      [ .[] | .fieldValues.nodes[]? | select(.field.name == "Status") | .name ]
      | group_by(.)
      | map({status: .[0], count: length})
      | sort_by(-.count)
      | map("\(.status): \(.count)")
      | join(" - ")
    ')
    if [ -n "$status_summary" ] && [ "$status_summary" != "" ]; then
        echo "  "
        echo "**Status breakdown:** $status_summary"
    fi
    echo ""
    echo "---"
    echo ""
    echo "## Table of Contents"
    echo ""

    # Build TOC
    echo "$items_json" | jq -r '
      to_entries[] |
      .key as $i |
      .value as $item |
      ($item.content.__typename // "ProjectItem") as $type |
      ($item.content.title //
        ([$item.fieldValues.nodes[]? | select(.field.name == "Title") | .text] | first) //
        "Untitled") as $title |
      ($item.content.number // null) as $num |
      (if $num then "#\($num) - \($title)" else $title end) as $label |
      "- [\($i + 1). \($label)](#item-\($i + 1))"
    '
    echo ""
    echo "---"
    echo ""

    # Emit each item
    count=$(echo "$items_json" | jq 'length')
    i=0
    while [ "$i" -lt "$count" ]; do
        item=$(echo "$items_json" | jq -c ".[$i]")
        idx=$((i + 1))

        type=$(echo "$item" | jq -r '.content.__typename // "ProjectItem"')

        # Resolve title
        title=$(echo "$item" | jq -r '.content.title // empty')
        if [ -z "$title" ]; then
            title=$(echo "$item" | jq -r '[.fieldValues.nodes[]? | select(.field.name == "Title") | .text] | first // "Untitled"')
        fi

        number=$(echo "$item" | jq -r '.content.number // empty')
        url=$(echo "$item" | jq -r '.content.url // empty')
        repo_owner=$(echo "$item" | jq -r '.content.repository.owner.login // empty')
        repo_name=$(echo "$item" | jq -r '.content.repository.name // empty')
        state=$(echo "$item" | jq -r '.content.state // empty')
        merged=$(echo "$item" | jq -r '.content.merged // empty')
        author=$(echo "$item" | jq -r '.content.author.login // .content.creator.login // empty')
        created=$(echo "$item" | jq -r '.content.createdAt // empty')
        body=$(echo "$item" | jq -r '.content.body // empty')

        # Heading
        case "$type" in
            Issue)       icon="Issue" ;;
            PullRequest) icon="Pull Request" ;;
            DraftIssue)  icon="Draft Issue" ;;
            *)           icon="Project Card" ;;
        esac

        if [ -n "$number" ]; then
            heading_title="#$number - $title"
        else
            heading_title="$title"
        fi

        # Only prefix the heading with type for real Issues / Pull Requests; draft issues
        # and standalone project cards just use the title (type is still shown in the table).
        case "$type" in
            Issue|PullRequest)
                echo "## <a id=\"item-$idx\"></a>$idx. $icon: $heading_title"
                ;;
            *)
                echo "## <a id=\"item-$idx\"></a>$idx. $heading_title"
                ;;
        esac
        echo ""


        # Metadata table - emit rows in a fixed, predictable order:
        #   Type, Repository, Link, State, Status, Day, Author, Created, Assignees, Labels,
        #   then any remaining custom fields in their natural order.
        echo "| Field | Value |"
        echo "| --- | --- |"
        echo "| Type | $icon |"
        if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
            echo "| Repository | \`$repo_owner/$repo_name\` |"
        fi
        if [ -n "$number" ] && [ -n "$url" ]; then
            echo "| Link | [#$number]($url) |"
        elif [ -n "$url" ]; then
            echo "| Link | [$url]($url) |"
        fi
        if [ -n "$state" ]; then
            if [ "$type" = "PullRequest" ] && [ "$merged" = "true" ]; then
                echo "| State | MERGED |"
            else
                echo "| State | $state |"
            fi
        fi

        # Pull out Status and Day custom fields up front so they appear in a consistent slot.
        status_value=$(echo "$item" | jq -r '[.fieldValues.nodes[]? | select(.field.name == "Status") | (.text // .name // .title // .date // (.number | tostring?))] | first // empty')
        day_value=$(echo "$item" | jq -r '[.fieldValues.nodes[]? | select(.field.name == "Day") | (.text // .name // .title // .date // (.number | tostring?))] | first // empty')
        if [ -n "$status_value" ]; then
            echo "| Status | $status_value |"
        fi
        if [ -n "$day_value" ]; then
            echo "| Day | $day_value |"
        fi

        if [ -n "$author" ]; then
            echo "| Author | @$author |"
        fi
        if [ -n "$created" ]; then
            created_fmt=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" "+%Y-%m-%d" 2>/dev/null || echo "$created")
            echo "| Created | $created_fmt |"
        fi

        # Assignees
        assignees=$(echo "$item" | jq -r '[.content.assignees.nodes[]?.login] | map("@" + .) | join(", ")')
        if [ -n "$assignees" ]; then
            echo "| Assignees | $assignees |"
        fi

        # Labels
        labels=$(echo "$item" | jq -r '[.content.labels.nodes[]?.name] | map("`" + . + "`") | join(", ")')
        if [ -n "$labels" ]; then
            echo "| Labels | $labels |"
        fi

        # Remaining custom field values (Title/Description/Body excluded; Status/Day already emitted)
        echo "$item" | jq -r '
          .fieldValues.nodes[]?
          | select(.field.name != null
                   and (.field.name | IN("Title", "Description", "Body", "Status", "Day") | not))
          | "| " + .field.name + " | " + (
              (.text // .name // .title // .date // (.number | tostring?)) // ""
            ) + " |"
        '
        echo ""

        # Description
        if [ -n "$body" ] && [ "$body" != "null" ]; then
            echo "### Description"
            echo ""
            # Emit raw markdown body so embedded formatting renders
            printf "%s\n" "$body"
            echo ""
        fi

        # Comments (Issue / PR)
        comment_count=$(echo "$item" | jq '[.content.comments.nodes[]?] | length')
        if [ "$comment_count" -gt 0 ]; then
            echo "### Comments ($comment_count)"
            echo ""
            ci=0
            while [ "$ci" -lt "$comment_count" ]; do
                comment=$(echo "$item" | jq -c ".content.comments.nodes[$ci]")
                c_author=$(echo "$comment" | jq -r '.author.login // "unknown"')
                c_created=$(echo "$comment" | jq -r '.createdAt // ""')
                c_body=$(echo "$comment" | jq -r '.body // ""')
                if [ -n "$c_created" ]; then
                    c_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$c_created" "+%Y-%m-%d %H:%M UTC" 2>/dev/null || echo "$c_created")
                else
                    c_date="unknown date"
                fi
                echo "#### @$c_author - $c_date"
                echo ""
                if [ -n "$c_body" ] && [ "$c_body" != "null" ]; then
                    printf "%s\n" "$c_body"
                else
                    echo "_(no content)_"
                fi
                echo ""
                ci=$((ci + 1))
            done
        fi

        echo "---"
        echo ""

        i=$((i + 1))
    done
} > "$output_file"

echo "✅ Done. Wrote $total items to $output_file" >&2
