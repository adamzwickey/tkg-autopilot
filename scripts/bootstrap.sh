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
mv tkg-extensions-manifests-* tkg-extensions-manifests

# Initialize TKG
tkg get mc
# Write needed values into TKG config file
export AWS_B64ENCODED_CREDENTIALS=
export AWS_ACCESS_KEY_ID=$(yq r $VARS_YAML aws.accessKey)
export AWS_SECRET_ACCESS_KEY=$(yq r $VARS_YAML aws.secretKey)
export AWS_REGION=$(yq r $VARS_YAML aws.region)
tkg config permissions aws

yq write $HOME/.tkg/config.yaml -i "SERVICE_CIDR" 100.64.0.0/13
yq write $HOME/.tkg/config.yaml -i "CLUSTER_CIDR" 100.96.0.0/11
yq write $HOME/.tkg/config.yaml -i "MACHINE_HEALTH_CHECK_ENABLED" true
yq write $HOME/.tkg/config.yaml -i "AWS_PUBLIC_SUBNET_ID" $(yq r $VARS_YAML aws.publicSubnet1)
yq write $HOME/.tkg/config.yaml -i "AWS_PUBLIC_SUBNET_ID_1" $(yq r $VARS_YAML aws.publicSubnet2)
yq write $HOME/.tkg/config.yaml -i "AWS_PUBLIC_SUBNET_ID_2" $(yq r $VARS_YAML aws.publicSubnet3)
yq write $HOME/.tkg/config.yaml -i "AWS_PRIVATE_SUBNET_ID" $(yq r $VARS_YAML aws.privateSubnet1)
yq write $HOME/.tkg/config.yaml -i "AWS_PRIVATE_SUBNET_ID_1" $(yq r $VARS_YAML aws.privateSubnet2)
yq write $HOME/.tkg/config.yaml -i "AWS_PRIVATE_SUBNET_ID_2" $(yq r $VARS_YAML aws.privateSubnet3)
yq write $HOME/.tkg/config.yaml -i "AWS_NODE_AZ" $(yq r $VARS_YAML aws.az1)
yq write $HOME/.tkg/config.yaml -i "AWS_NODE_AZ_1" $(yq r $VARS_YAML aws.az2)
yq write $HOME/.tkg/config.yaml -i "AWS_NODE_AZ_2" $(yq r $VARS_YAML aws.az3)
yq write $HOME/.tkg/config.yaml -i "CONTROL_PLANE_MACHINE_TYPE" t3.medium
yq write $HOME/.tkg/config.yaml -i "NODE_MACHINE_TYPE" t3.xlarge
yq write $HOME/.tkg/config.yaml -i "AWS_SSH_KEY_NAME" $(yq r $VARS_YAML aws.keyPairName)
yq write $HOME/.tkg/config.yaml -i "AWS_VPC_ID" $(yq r $VARS_YAML aws.vpcId)
yq write $HOME/.tkg/config.yaml -i "AWS_REGION" $(yq r $VARS_YAML aws.region)
yq write $HOME/.tkg/config.yaml -i "BASTION_HOST_ENABLED" false
cat $HOME/.tkg/config.yaml

MGMT_PLAN=$(yq r $VARS_YAML tkg.mgmt.plan)
tkg init -i aws -p $MGMT_PLAN --ceip-participation false --name $(yq r $VARS_YAML tkg.mgmt.name) --cni antrea -v 8

# Install Ingress

# Install Exernal DNS

# Install ArgoCD