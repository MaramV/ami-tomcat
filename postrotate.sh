#!/bin/bash

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/placement/region)
EC2_DATA=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document)

ACCOUNT_ID=$(echo $EC2_DATA | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["accountId"]')

echo "Instance Id: $INSTANCE_ID, $REGION"


NAME=$(aws ec2 describe-tags --filters --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" --query "Tags[?Key=='Name'].Value" --output text)

SOURCE="/usr/share/tomcat/logs/"
DEST="s3://$ACCOUNT_ID-tomcat-logs/$NAME/$INSTANCE_ID"

echo $SOURCE
echo $DEST

aws s3 sync $SOURCE $DEST --exclude "*" --include "*.gz"