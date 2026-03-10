#!/bin/bash
ids=$(aws ec2 describe-images --owners self | jq -r ".Images[].ImageId")
account=$(aws sts get-caller-identity | jq -r .Account)

for i in $ids
do
  value=$(aws ec2 describe-instances --filters "Name=image-id,Values=$i" | jq -r ".Reservations[].OwnerId")
  if [[ "$value" == "$account" ]]; then
    echo "removing ami $i"
    aws ec2 deregister-image --image-id $i
  fi
done