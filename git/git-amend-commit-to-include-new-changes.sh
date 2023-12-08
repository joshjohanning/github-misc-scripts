#!/bin/bash

# amends the most recent commit by adding newly staged changes

git add .
git commit --amend -m "feat: adding a new feature"
git commit --amend --no-edit # && git push --force-with-lease

# note: you need to force push if you've already pushed the commit to the remote
# note: this can affect pr's and cause merge conflicts for already-created pr's since the bases will be different
