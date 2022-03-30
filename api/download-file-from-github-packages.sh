#!/bin/bash

# Notes: This appears to be an undocumented API - use this as a reference to form your own url
curl 'https://maven.pkg.github.com/joshjohanning-org/sherlock-heroku-poc-mvn-package/com/sherlock/herokupoc/1.0.0-202201071559/herokupoc-1.0.0-202201071559.jar' \
    -H "Authorization: Bearer ${PAT}" \
    -L \
    -O \
    -v
