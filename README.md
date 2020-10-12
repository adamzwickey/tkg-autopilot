# tkg-autopilot
This project is meant to automate the paving of TKG enfirments, including common extensions, in AWS.  It utilizes TKG, Helm, and ArgoCD utilizing the App of Apps pattern

![home](https://gitlab.com/azwickey/tkg-autopilot/-/raw/master/img/argo.png "argo")

aws ec2 get-launch-template-data --instance-id i-0cc81778add99f3f1 --query "LaunchTemplateData"

aws ec2 create-launch-template \
    --launch-template-name tkg-template \
    --version-description Version1 \
    --tag-specifications 'ResourceType=launch-template,Tags=[{Key=purpose,Value=demo}]' \
    --launch-template-data file://template.json

aws ec2 delete-launch-template --launch-template-id lt-0e44291fc8e5f4f1e --region us-east-2

aws ec2 run-instances --launch-template LaunchTemplateId=lt-0f9c0e09f11b7c295,Version=1

aws s3 cp vars.yaml s3://tkg-autopilot/vars.yaml 

# Autocomplete
alias k=kubectl
echo 'alias k=kubectl' >>~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
echo 'complete -F __start_kubectl k' >>~/.bashrc
source ~/.bashrc
