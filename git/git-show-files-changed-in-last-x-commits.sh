#!/bin/bash

# shows files that have been changed (added, modified, etc.) in the last x commits

echo ""
echo "files modified (-M) in the last 10 commits:"
git diff-tree --compact-summary --diff-filter=M -r HEAD~10..HEAD

echo ""
echo "files added (-A) in the last 10 commits:"
git diff-tree --compact-summary --diff-filter=A -r HEAD~10..HEAD

# --diff-filter=[ACDMRTUXB*]

# Select only files that are

# A Added
# C Copied
# D Deleted
# M Modified
# R Renamed
# T have their type (mode) changed
# U Unmerged
# X Unknown
# B have had their pairing Broken
# * All-or-none

# Also, these upper-case letters can be downcased to exclude.  E.g.
# `--diff-filter=ad` excludes added and deleted paths.
