#!/usr/bin/env bash
#
# Script to deploy two EKS clusters for CloudNativePG demonstration
# purposes.

# Create the S3 Bucket in the eu-central-1 region
aws s3api create-bucket \
  --bucket osld-it23-eu-central-1 \
  --region eu-central-1 \
  --create-bucket-configuration \
  --no-cli-pager \
  LocationConstraint=eu-central-1

aws s3api put-public-access-block \
    --bucket osld-it23-eu-central-1 \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create the S3 Bucket in the eu-west-1 region
aws s3api create-bucket \
  --bucket osld-it23-eu-west-1 \
  --region eu-west-1 \
  --create-bucket-configuration \
  --no-cli-pager \
  LocationConstraint=eu-west-1

aws s3api put-public-access-block \
    --bucket osld-it23-eu-west-1 \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create the EKS cluster in the eu-central-1 region
eksctl create cluster -f osld-it23-eu-central-1.yaml
# Create the EKS cluster in the eu-west-1 region
eksctl create cluster -f osld-it23-eu-west-1.yaml
