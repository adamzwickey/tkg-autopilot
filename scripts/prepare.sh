
#!/bin/bash -e
PARAMS_YAML=vars.yaml

#Prepare AWS template
INSTANCE_PROFILE=$(yq r $PARAMS_YAML aws.instanceProfileARN)
SECURITY_GROUP=$(yq r $PARAMS_YAML aws.securityGroup)
SUBNET=$(yq r $PARAMS_YAML aws.publicSubnet)
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
LT_ID=$(yq r lt.yaml LaunchTemplate.LaunchTemplateId)
EC2_INSTANCE_YAML=$(aws ec2 run-instances --launch-template LaunchTemplateId=$LT_ID,Version=1 --output yaml)
echo $EC2_INSTANCE_YAML
