#!/usr/bin/env bash
#
# Script to deploy two EKS clusters for CloudNativePG demonstration
# purposes.

# Shortcut to install volume snapshots
function prepareVolumeSnapshots()
{
    kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter//client/config/crd | kubectl apply -f -
    kubectl -n kube-system kustomize https://github.com/kubernetes-csi/external-snapshotter//deploy/kubernetes/snapshot-controller | kubectl apply -f -
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/snapshot/manifests/classes/snapshotclass.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/snapshot/manifests/classes/storageclass.yaml
}

# Create the S3 Bucket in the eu-central-1 region
aws s3api create-bucket \
  --bucket jeeg-eu-central-1 \
  --region eu-central-1 \
  --create-bucket-configuration \
  --no-cli-pager \
  LocationConstraint=eu-central-1

aws s3api put-public-access-block \
    --bucket jeeg-eu-central-1 \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create the S3 Bucket in the eu-west-1 region
aws s3api create-bucket \
  --bucket jeeg-eu-west-1 \
  --region eu-west-1 \
  --create-bucket-configuration \
  --no-cli-pager \
  LocationConstraint=eu-west-1

aws s3api put-public-access-block \
    --bucket jeeg-eu-west-1 \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create the EKS cluster in the eu-central-1 region
eksctl create cluster -f jeeg-eu-central-1.yaml
prepareVolumeSnapshots

# Create the EKS cluster in the eu-west-1 region
eksctl create cluster -f jeeg-eu-west-1.yaml
prepareVolumeSnapshots

