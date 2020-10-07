#!/bin/bash -e

INSTANCE_ID=$(yq r ec2.yaml -d0 'Instances[0].InstanceId')
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

# Cleanup clusters
echo Public IP of instance: $PUBLIC_IP
ssh -i keys/tkg-aws-ssh.pem ec2-user@$PUBLIC_IP sudo /tkg-autopilot/scripts/delete-tkg.sh

echo Deleting instance $INSTANCE_ID
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --output yaml

LT_ID=$(yq r lt.yaml LaunchTemplate.LaunchTemplateId)
echo Deleting Launch Template $LT_ID
aws ec2 delete-launch-template --launch-template-id $LT_ID --region us-east-2 --output yaml