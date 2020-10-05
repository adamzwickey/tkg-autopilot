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
rm *.tar.gz
mv tkg-extensions-* tkg-extensions-manifests

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
# once created we'll upload kube and tkg config files for use in local workstation if needed
aws s3 cp $HOME/.tkg/config.yaml s3://tkg-autopilot/config.yaml  
aws s3 cp $HOME/.kube/config s3://tkg-autopilot/kubeconfig  


cd /tkg-autopilot
kubectl apply -f manifests/mgmt/cluster-issuer.yaml
# Install Ingress
kubectl apply -f assets/tkg-extensions-manifests/extensions/tmc-extension-manager.yaml
kubectl apply -f assets/tkg-extensions-manifests/extensions/kapp-controller.yaml
kubectl apply -f assets/tkg-extensions-manifests/extensions/ingress/contour/namespace-role.yaml
kubectl create secret generic contour-data-values --from-file=values.yaml=manifests/mgmt/contour-data-values.yaml -n tanzu-system-ingress
kubectl apply -f assets/tkg-extensions-manifests/extensions/ingress/contour/contour-extension.yaml

# Install Exernal DNS
yq write manifests/mgmt/values-external-dns.yaml -i "aws.credentials.secretKey" $(yq r $VARS_YAML aws.accessKey)
yq write manifests/mgmt/values-external-dns.yaml -i "aws.credentials.accessKey" $(yq r $VARS_YAML aws.secretKey)
yq write manifests/mgmt/values-external-dns.yaml -i "aws.region" $(yq r $VARS_YAML aws.region)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm upgrade --install external-dns bitnami/external-dns -n tanzu-system-ingress -f manifests/mgmt/values-external-dns.yaml
#Wait for pod to be ready
while kubectl get po -l app.kubernetes.io/name=external-dns -n tanzu-system-ingress | grep Running ; [ $? -ne 0 ]; do
	echo external-dns is not yet ready
	sleep 5s
done
kubectl annotate service envoy "external-dns.alpha.kubernetes.io/hostname=$(yq r $VARS_YAML tkg.mgmt.ingress)." -n tanzu-system-ingress --overwrite

# Install ArgoCD
kubectl create ns argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -f manifests/mgmt/values-argo.yaml  -n argocd
kubectl apply -f generated/$(yq r $PARAMS_YAML shared-services-cluster.name)/argocd/httpproxy.yaml