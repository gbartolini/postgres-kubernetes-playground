#!/usr/bin/env bash
#
# Script to remove the two EKS clusters that had been
# previously set up for CloudNativePG demonstration purposes.

# Delete the primary S3 bucket
aws s3api delete-bucket --bucket kcd-it23-eu-central-1 --region eu-central-1

# Delete the secondary S3 bucket
aws s3api delete-bucket --bucket kcd-it23-eu-west-1 --region eu-west-1

# Delete the primary cluster
eksctl delete cluster -f kcd-it23-eu-central-1.yaml --disable-nodegroup-eviction --force

# Delete the secondary cluster
eksctl delete cluster -f kcd-it23-eu-west-1.yaml --disable-nodegroup-eviction --force
