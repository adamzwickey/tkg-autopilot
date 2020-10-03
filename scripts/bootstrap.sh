#!/usr/bin/env bash
echo "Bootstrapping TKG!!!!"

#Pull down assets from S3 bucket
mkdir assets
aws s3 sync s3://tkg-autopilot assets   # This needs to be externalized
VARS_YAML=/tkg-autopilot/assets/vars.yaml
echo config YAML:
cat $VARS_YAML
cd assets
# TKG
tar -zxvf tkg-linux*
chmod u+x tkg/*
chmod o+x tkg/*
mv tkg/imgpkg-linux-* /usr/bin/imgpkg
mv tkg/kapp-linux-* /usr/bin/kapp
mv tkg/kbld-linux-* /usr/bin/kbld
mv tkg/tkg-linux-* /usr/bin/tkg
mv tkg/ytt-linux-* /usr/bin/ytt

# TKG Extensions
tar -zxvf tkg-extensions-manifests-*

# Initialize TKG
HOME=/root
tkg get mc
# Write needed values into TKG config file
yq write ~/.tkg/config.yaml -i "SERVICE_CIDR" 100.64.0.0/13
yq write ~/.tkg/config.yaml -i "CLUSTER_CIDR" 100.96.0.0/11
yq write ~/.tkg/config.yaml -i "MACHINE_HEALTH_CHECK_ENABLED" true
yq write ~/.tkg/config.yaml -i "AWS_B64ENCODED_CREDENTIALS" ""
yq write ~/.tkg/config.yaml -i "AWS_PUBLIC_SUBNET_ID" $(yq r $VARS_YAML aws.publicSubnet1)
yq write ~/.tkg/config.yaml -i "AWS_PUBLIC_SUBNET_ID_1" $(yq r $VARS_YAML aws.publicSubnet2)
yq write ~/.tkg/config.yaml -i "AWS_PUBLIC_SUBNET_ID_2" $(yq r $VARS_YAML aws.publicSubnet3)
yq write ~/.tkg/config.yaml -i "AWS_PRIVATE_SUBNET_ID" $(yq r $VARS_YAML aws.privateSubnet1)
yq write ~/.tkg/config.yaml -i "AWS_PRIVATE_SUBNET_ID_1" $(yq r $VARS_YAML aws.privateSubnet2)
yq write ~/.tkg/config.yaml -i "AWS_PRIVATE_SUBNET_ID_2" $(yq r $VARS_YAML aws.privateSubnet3)
yq write ~/.tkg/config.yaml -i "AWS_NODE_AZ" us-east-2a
yq write ~/.tkg/config.yaml -i "AWS_NODE_AZ_1" us-east-2b
yq write ~/.tkg/config.yaml -i "AWS_NODE_AZ_2" us-east-2c
yq write ~/.tkg/config.yaml -i "CONTROL_PLANE_MACHINE_TYPE" t3.medium
yq write ~/.tkg/config.yaml -i "NODE_MACHINE_TYPE" t3.xlarge
yq write ~/.tkg/config.yaml -i "AWS_SSH_KEY_NAME" $(yq r $VARS_YAML aws.keyPairName)
yq write ~/.tkg/config.yaml -i "AWS_VPC_ID" $(yq r $VARS_YAML aws.vpcId)
yq write ~/.tkg/config.yaml -i "AWS_REGION" us-east-2
cat ~/.tkg/config.yaml

MGMT_PLAN=$(yq r $VARS_YAML tkg.mgmt.plan)
tkg init -i aws -p $MGMT_PLAN --ceip-participation false --name aws-mgmt --cni antrea -v 8

