#!/bin/bash

# counts committers in the last 90 days

git shortlog --group=committer --summary --since "3 months" | wc -l | tr -d ' '
