#!/usr/bin/env bash
echo "Bootstrapping TKG!!!!"

#Pull down assets from S3 bucket
mkdir assets
aws s3 sync s3://$2 assets   # This needs to be externalized
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
aws s3 cp $HOME/.tkg/config.yaml s3://$2/config.yaml  
aws s3 cp $HOME/.kube/config s3://$2/kubeconfig  
tkg scale cluster aws-mgmt -n tkg-system -w 3

cd /tkg-autopilot
kubectl apply -f manifests/mgmt/cluster-issuer.yaml
# Install Exernal DNS
helm repo add bitnami https://charts.bitnami.com/bitnami
yq write manifests/mgmt/values-external-dns.yaml -i "aws.credentials.secretKey" $(yq r $VARS_YAML aws.secretKey)
yq write manifests/mgmt/values-external-dns.yaml -i "aws.credentials.accessKey" $(yq r $VARS_YAML aws.accessKey)
yq write manifests/mgmt/values-external-dns.yaml -i "aws.region" $(yq r $VARS_YAML aws.region)
yq write manifests/mgmt/values-external-dns.yaml -i "txtOwnerId" $(yq r $VARS_YAML aws.hostedZoneId)
helm install external-dns-aws bitnami/external-dns -f manifests/mgmt/values-external-dns.yaml
#Wait for pod to be ready
while kubectl get po -l app.kubernetes.io/name=external-dns | grep Running ; [ $? -ne 0 ]; do
	echo external-dns is not yet ready
	sleep 5s
done

# Install ArgoCD
kubectl create ns argocd
helm repo add argo https://argoproj.github.io/argo-helm
export ARGOCD_PWD=$(yq r $VARS_YAML tkg.mgmt.argo.pwd)
echo "argopwd: $ARGOCD_PWD"
export ARGOCD_PWD_ENCODE=$(htpasswd -nbBC 10 "" $ARGOCD_PWD | tr -d ':\n' | sed 's/$2y/$2a/')
echo "Encoded argopwd: $ARGOCD_PWD_ENCODE"
yq write manifests/mgmt/values-argo.yaml -i "configs.secret.argocdServerAdminPassword" $ARGOCD_PWD_ENCODE
yq write manifests/mgmt/values-argo.yaml -i "server.certificate.domain" $(yq r $VARS_YAML tkg.mgmt.argo.ingress)
yq write manifests/mgmt/values-argo.yaml -i 'server.service.annotations."external-dns.alpha.kubernetes.io/hostname"' $(yq r $VARS_YAML tkg.mgmt.argo.ingress) 
helm install argocd argo/argo-cd -f manifests/mgmt/values-argo.yaml  -n argocd

#Wait for argo and ingress to be ready
while nslookup $(yq r $VARS_YAML tkg.mgmt.argo.ingress) | grep Name ; [ $? -ne 0 ]; do
	echo Argo Server and DNS is not yet ready
	sleep 5s
done

export MGMT_CLUSTER=$(yq r $VARS_YAML tkg.mgmt.name)
kubectl config use-context $MGMT_CLUSTER-admin@$MGMT_CLUSTER
kubectl create serviceaccount argocd -n argocd
kubectl create clusterrolebinding argocd --clusterrole=cluster-admin --serviceaccount=argocd:argocd
export TOKEN_SECRET=$(kubectl get serviceaccount -n argocd argocd -o jsonpath='{.secrets[0].name}')
export TOKEN=$(kubectl get secret -n argocd $TOKEN_SECRET -o jsonpath='{.data.token}' | base64 --decode)
kubectl config set-credentials $MGMT_CLUSTER-argocd-token-user --token $TOKEN
kubectl config set-context $MGMT_CLUSTER-argocd-token-user@$MGMT_CLUSTER \
  --user $MGMT_CLUSTER-argocd-token-user \
  --cluster $MGMT_CLUSTER
# Add the config setup with the service account
argocd login $(yq r $VARS_YAML tkg.mgmt.argo.ingress) \
  --username admin \
  --password $ARGOCD_PWD \
  --insecure  #Need this as we don't have a signed cert yet
argocd cluster add $MGMT_CLUSTER-argocd-token-user@$MGMT_CLUSTER

# Add Mgmt Cluster App of Apps
SERVER=$(argocd cluster list | grep $MGMT_CLUSTER-argocd-token-user@$MGMT_CLUSTER | awk '{print $1}')
argocd app create mgmt-app-of-apps \
  --repo $REPO.git \
  --dest-server $SERVER \
  --dest-namespace default \
  --sync-policy automated \
  --path cd/argo/mgmt \
  --helm-set server=$SERVER \
  --helm-set dex.clientSecret=$(yq r $VARS_YAML tkg.mgmt.dex.oidcSecret) \
  --helm-set dex.wlClientSecret1=$(yq r $VARS_YAML tkg.mgmt.dex.wlClientSecret) \
  --helm-set argo.pwd="$(yq r $VARS_YAML tkg.mgmt.argo.pwd)"

  # We wait for the workload cluster(s) to be added to Argo and then add the secret vars
  