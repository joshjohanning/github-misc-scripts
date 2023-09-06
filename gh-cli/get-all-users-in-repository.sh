#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 <org> <repo>"
  echo "Example: ./get-all-users-in-repository joshjohanning-org ghas-demo"
  exit 1
fi

org="$1"
repo="$2"

# export GH_HOST=ghes.mycompany.com

issue_comments=$(gh api --paginate /repos/$org/$repo/issues/comments | jq -r '.[].user.login' | sort | uniq)
pr_comments=$(gh api --paginate /repos/$org/$repo/pulls/comments | jq -r '.[].user.login' | sort | uniq)
issues=$(gh api --paginate /repos/$org/$repo/issues | jq -r '.[].user.login' | sort | uniq)
prs=$(gh api --paginate /repos/$org/$repo/pulls | jq -r '.[].user.login' | sort | uniq)
# commits=$(gh api --paginate /repos/$org/$repo/commits | jq -r '.[].committer.login' | sort | uniq) # <-- if want to include committers

# combine all the users into a single list
users=$(echo -e "$issue_comments\n$pr_comments\n$pr_reviews\n$issues\n$prs" | sort | uniq)
# users=$(echo -e "$issue_comments\n$pr_comments\n$pr_reviews\n$issues\n$prs\n$commits" | sort | uniq) # <-- if want to include committers

echo "$users"
