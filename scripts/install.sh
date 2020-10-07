
#!/bin/bash -e
PARAMS_YAML=vars.yaml

#Prepare AWS template
INSTANCE_PROFILE=$(yq r $PARAMS_YAML aws.instanceProfileARN)
SECURITY_GROUP=$(yq r $PARAMS_YAML aws.securityGroup)
SUBNET=$(yq r $PARAMS_YAML aws.publicSubnet1)
KEYNAME=$(yq r $PARAMS_YAML aws.keyPairName)
USER_DATA=$(cat scripts/init.sh | base64 )
sed -e 's|INSTANCE_PROFILE|'$INSTANCE_PROFILE'|g' \
    -e 's|SECURITY_GROUP|'$SECURITY_GROUP'|g' \
    -e 's|SUBNET|'$SUBNET'|g' \
    -e 's|KEYNAME|'$KEYNAME'|g' \
    -e 's|USER_DATA|'$USER_DATA'|g' \
    template.json > custom-template.json

TEMPLATE_YAML=$(aws ec2 create-launch-template \
    --launch-template-name tkg-template \
    --version-description Version1 \
    --tag-specifications 'ResourceType=launch-template,Tags=[{Key=purpose,Value=demo}]' \
    --launch-template-data file://custom-template.json \
    --output yaml)
echo $TEMPLATE_YAML > lt.yaml
echo "Launch Template: $(cat lt.yaml)"
LT_ID=$(yq r lt.yaml LaunchTemplate.LaunchTemplateId)
EC2_INSTANCE_YAML=$(aws ec2 run-instances --launch-template LaunchTemplateId=$LT_ID,Version=1 --output yaml)
echo $EC2_INSTANCE_YAML > ec2.yaml
echo "Bootstrapper Instance: $(cat ec2.yaml)"

INSTANCE_ID=$(yq r ec2.yaml -d0 'Instances[0].InstanceId')
PUBLIC_IP=
while [ -z "$PUBLIC_IP" ] ; do
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
    echo public ip... $PUBLIC_IP
    sleep 1  #Loop until its ready
done
sleep 10 # Need time for SSH process to startup... usually takes just a few secs
ssh -i keys/tkg-aws-ssh.pem ec2-user@$PUBLIC_IP sudo tail -f /var/log/cloud-init-output.log