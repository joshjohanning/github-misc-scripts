#!/bin/bash

### Option 1: ###

# fetch all tags:
git fetch --all --tags

# checkout tag as a branch:
git checkout tags/v1.0 -b v1.0-branch

### Option 2: ###

# find the latest tag to checkout:
tag=$(git describe --tags `git rev-list --tags --max-count=1`)

# checkout the latest tag into a branch called latest:
git checkout $tag -b latest
