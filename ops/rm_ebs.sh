#!/bin/bash
ids=$(aws ec2 describe-snapshots --filter "Name=tag:Name,Values=slap" | jq -r ".Snapshots[].SnapshotId")
for i in $ids
do
  echo "removing snapshot $i"
  aws ec2 delete-snapshot --snapshot-id $i
done