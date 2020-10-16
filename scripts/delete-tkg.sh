#!/bin/bash -e
# Cleanup clusters
VARS_YAML=/tkg-autopilot/assets/vars.yaml
export AWS_B64ENCODED_CREDENTIALS=
export AWS_ACCESS_KEY_ID=$(yq r $VARS_YAML aws.accessKey)
export AWS_SECRET_ACCESS_KEY=$(yq r $VARS_YAML aws.secretKey)
export AWS_REGION=$(yq r $VARS_YAML aws.region)

tkg delete cluster $(yq r $VARS_YAML tkg.workload1.name) -y 
tkg delete cluster $(yq r $VARS_YAML tkg.workload2.name) -y 
sleep 10
while tkg get clusters --config config.yaml | grep deleting  ; [ $? -eq 0 ]; do
	echo Clusters still deleting
	sleep 5s
done

tkg delete mc $(yq r $VARS_YAML tkg.mgmt.name) -y