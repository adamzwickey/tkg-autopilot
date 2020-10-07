#!/bin/bash -e
# Cleanup clusters
VARS_YAML=/tkg-autopilot/assets/vars.yaml
export AWS_B64ENCODED_CREDENTIALS=
export AWS_ACCESS_KEY_ID=$(yq r $VARS_YAML aws.accessKey)
export AWS_SECRET_ACCESS_KEY=$(yq r $VARS_YAML aws.secretKey)
export AWS_REGION=$(yq r $VARS_YAML aws.region)

tkg delete mc $(yq r $VARS_YAML tkg.mgmt.name) -y