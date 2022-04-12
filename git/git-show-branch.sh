#!/bin/bash

# shows commits that are common for branches being compared

git show-branch master fixes mhf

# returns: 
# * [master] Add 'git show-branch'.
#  ! [fixes] Introduce "reset type" flag to "git reset"
#   ! [mhf] Allow "+remote:local" refspec to cause --force when fetching.
# ---
#   + [mhf] Allow "+remote:local" refspec to cause --force when fetching.
#   + [mhf~1] Use git-octopus when pulling more than one heads.
#  +  [fixes] Introduce "reset type" flag to "git reset"
#   + [mhf~2] "git fetch --force".
#   + [mhf~3] Use .git/remote/origin, not .git/branches/origin.
#   + [mhf~4] Make "git pull" and "git fetch" default to origin
#   + [mhf~5] Infamous 'octopus merge'
#   + [mhf~6] Retire git-parse-remote.
#   + [mhf~7] Multi-head fetch.
#   + [mhf~8] Start adding the $GIT_DIR/remotes/ support.
# *++ [master] Add 'git show-branch'.
# These three branches all forked from a common commit, [master], whose commit message is "Add 'git show-branch'". The "fixes" branch adds one commit "Introduce "reset type" flag to "git reset"". The "mhf" branch adds many other commits. The current branch is "master".

## see: https://git-scm.com/docs/git-show-branch