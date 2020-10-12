#!/usr/bin/env bash

echo "***********************"
echo "Preparing pre-req tools"
echo "***********************"
# Docker install
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo docker info

# kubectl install
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod u+x kubectl
chmod o+x kubectl
sudo mv kubectl /usr/bin

# Helm
wget https://get.helm.sh/helm-v3.3.4-linux-amd64.tar.gz
tar -zxvf helm*
mv linux-amd64/helm /usr/bin/helm
rm -rf linux*

# Git client install
sudo yum install git -y
git version

# yq
wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_amd64
chmod u+x yq_linux_amd64 
chmod o+x yq_linux_amd64 
sudo mv yq_linux_amd64 /usr/bin/yq

# ArgoCD
wget https://github.com/argoproj/argo-cd/releases/download/v1.7.7/argocd-linux-amd64
chmod u+x argocd-linux-amd64
chmod o+x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/bin/argocd 
sudo yum install httpd-tools -y  #used for Arco admin PWD

echo "Done with pre-reqs"

export REPO=REPO_VAR
export BUCKET=BUCKET_VAR

echo "***********************"
echo "Cloning bootstrap scripts"
echo "***********************"
# pull repo
git clone $REPO.git
# run script
cd tkg-autopilot/
export HOME=/root
source ./scripts/bootstrap.sh $REPO $BUCKET

