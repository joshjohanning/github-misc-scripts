#!/bin/bash

# Listing commits
## list of commits - into a single line
git log --oneline # first 7 digits of commit hash
git log --pretty=oneline # full commit hash
## list last n commits
git log -n 5 --oneline

# git show examples (show diffs ineline)
## show diffs of most recent commit
git show
## can add --oneline to condense hash and commit message into one line
git show --oneline
## ignoring whitespace, with file changed stats
git show -w --stat -p
## show diffs of most recent n commits in main
git show -n 5 main
## similar to git show, except it shows all commits with diffs
git log -p
