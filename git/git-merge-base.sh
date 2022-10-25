#!/bin/bash

# git merge-base - finds the best common ancestor(s) between two commits (you can use it to compare commits at the tip of comparing branches)

# see: https://git-scm.com/docs/git-merge-base

git merge-base A b

# returns the most common ancesntor of A and B as a commit hash