#!/bin/bash

### Option 1: ###

# to delete a tag from the server only:
git push --delete origin v1.0.1

### Option 2: ###

# delete tags locally then push:
git tag -d v1.0.1
git push origin --tags --force # --force is needed to delete tags from remote
