#!/bin/bash

# tag_name: tag name for the release, can be an existing tag or a new one
# target_commitish: value that will be the target for the release's tag. Required if the supplied tag_name does not reference an existing tag. Ignored if the tag_name already exists
# previous_tag_name: name of previous tag, has to exist
# configuration_file_path: path to configuration file, defaults to .github/release.yml

gh api -X POST /repos/joshjohanning-org/Test-Release-Notes/releases/generate-notes \
  --input - << EOF
{  
  "tag_name": "newest",
  "previous_tag_name": "new"
}
