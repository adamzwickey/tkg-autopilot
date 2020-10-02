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
sudo mv kubectl /usr/sbin

# Git client install
sudo yum install git -y
git version

echo "Done with pre-reqs"

echo "***********************"
echo "Cloning bootstrap scripts"
echo "***********************"
# pull repo
git clone https://gitlab.com/azwickey/tkg-autopilot.git
# run script
cd tkg-autopilot/
./scripts/bootstrap.sh

