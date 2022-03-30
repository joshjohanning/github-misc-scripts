#!/bin/bash

jq -n '{"enabled":true}' | gh api -X PUT /repos/joshjohanning-ghas-enablement/MyShuttle/actions/permissions --input -
