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

# Git client install
sudo yum install git -y
git version

# yq
wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_amd64
chmod u+x yq_linux_amd64 
chmod o+x yq_linux_amd64 
sudo mv yq_linux_amd64 /usr/bin/yq

echo "Done with pre-reqs"

echo "***********************"
echo "Cloning bootstrap scripts"
echo "***********************"
# pull repo
git clone https://gitlab.com/azwickey/tkg-autopilot.git
# run script
cd tkg-autopilot/
export HOME=/root
source ./scripts/bootstrap.sh

