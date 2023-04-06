#!/bin/bash

gh release download -R joshjohanning-org/private-release v0.0.1 -p '*.zip' --clobber

# Params:
# Version: Don't include a version (ie: `v0.0.1`) to download the latest release
# File patterns: `-p`` is for pattern matching, so you can download multiple files at once. Use `-p` for each pattern
# Clobber: `--clobber`` is for clobbering, so you can overwrite existing files, otherwise use `--skip-existing`
