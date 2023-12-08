#!/bin/bash

# reorders the last 2 commits

GIT_SEQUENCE_EDITOR="sed -i '' -n 'h;1n;2p;g;p'" git rebase -i HEAD~2

# on macos you need -i ''; on other platforms it may be without the '' after -i, like:
# # GIT_SEQUENCE_EDITOR="sed -i -n 'h;1n;2p;g;p'" git rebase -i HEAD~2

# see also; git rebase -i HEAD~2
# # https://stackoverflow.com/questions/2740537/reordering-of-commits
