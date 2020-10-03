#!/bin/bash -e

#How to cleanup clusters????

INSTANCE_ID=$(yq r ec2.yaml -d0 'Instances[0].InstanceId')
echo Deleting instance $INSTANCE_ID
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --output yaml

LT_ID=$(yq r lt.yaml LaunchTemplate.LaunchTemplateId)
echo Deleting Launch Template $LT_ID
aws ec2 delete-launch-template --launch-template-id $LT_ID --region us-east-2 --output yaml