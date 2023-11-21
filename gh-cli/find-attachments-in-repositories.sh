#!/bin/bash

# Usage: 
# ./find-attachments-in-repositories <org> <bool: GET_COMMENTS>
#
# Note:
# - The issues and comments API also bring in PRs
#

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <bool: GET_COMMENTS>"
  echo "Example: ./find-attachments-in-repositories joshjohanning-org true"
  exit 1
fi

ORG=$1
GET_COMMENTS=$2

repos=$(gh api --paginate /orgs/$ORG/repos --jq '.[].full_name')

for repo in $repos
do
    echo "> looking through $repo ..."
    prelim_issue_check=$(gh api --paginate /repos/$repo/issues --jq '.[].body' | grep -E "/assets/|/files/")

    if [ "$prelim_issue_check" = "" ] ; then
        echo "  ... no issues found with attachments ..."
    else
        echo "  ... found issues with attachments ..."
    fi

    if [ "$GET_COMMENTS" = true ] ; then
        prelim_comment_check=$(gh api --paginate /repos/$repo/issues/comments --jq '.[].body' | grep -E "/assets/|/files/")
        if [ "$prelim_comment_check" = "" ] ; then
            echo "  ... no comments found with attachments ..."
        else
            echo "  ... found comments with attachments ..."
        fi
    else
        prelim_comment_check=""
    fi

    if [ "$prelim_issue_check" = "" ] && [ "$prelim_comment_check" = "" ] ; then
        continue
    else
        # check for issues
        if [ "$prelim_issue_check" != "" ]; then
            issues=$(gh api --paginate /repos/$repo/issues --jq '.[].number')
            for issue in $issues
            do
                issue_content=$(gh api /repos/$repo/issues/$issue)
                if echo "$issue_content" | jq '.body' | grep -qE "/assets/|/files/"; then
                    echo "$issue_content" | jq -r '.html_url'
                fi
            done
        fi

        # check comments
        if [ "$GET_COMMENTS" = true ] &&  [ "$prelim_comment_check" != "" ]; then
            # we have to get issues again
            issues=$(gh api --paginate /repos/$repo/issues --jq '.[].number')
            for issue in $issues
            do
                comments=$(gh api --paginate /repos/$repo/issues/$issue/comments --jq '.[].id')
                for comment in $comments
                do
                    comment_content=$(gh api /repos/$repo/issues/comments/$comment)
                    if echo "$comment_content" | jq '.body' | grep -qE "/assets/|/files/"; then
                        echo "$comment_content" | jq -r '.html_url'
                    fi
                done
            done
        fi
    fi
done
