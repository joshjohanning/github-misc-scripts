#!/bin/bash

# resets the last 3 commits and squashes them into one commit
git reset --soft HEAD~3 && git commit -m "feat: adding feature"
