#!/bin/bash

########################################### Using curl ###########################################

# curl works easily for public releases

# Latest release:
curl -OLs https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64

# Specific release:
curl -OLs https://github.com/aquasecurity/tfsec/releases/download/v1.28.1/tfsec-linux-amd64

########################################### Using wget ###########################################

# Latest release:
# wget https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64

# Specific release:
# wget https://github.com/aquasecurity/tfsec/releases/download/v1.28.1/tfsec-linux-amd64

########################################### Using gh #############################################

# See ./download-private-release-artifact.sh for more arguments

# Latest release:
# gh release download -R aquasecurity/tfsec -p 'tfsec-linux-amd64'

# Specific release:
# gh release download -R aquasecurity/tfsec v1.28.1 -p 'tfsec-linux-amd64'
