#!/usr/bin/env bash

usage() {
cat <<EOF
This scripts facilitates the creation of 2 EKS clusters in different regions to
help you understand concepts related to running Postgres inside Kubernetes with
CloudNativePG. Please specify PREFIX, PRIMARY_REGION and SECONDARY_REGION.

$0 PREFIX PRIMARY_REGION SECONDARY_REGION

Example:
$0 cnpg eu-central-1 eu-west-1
EOF
exit 1
}

mangle() {
PRIMARY_REGION=$1
SECONDARY_REGION=$2
sed \
  -e "s/@@CLUSTER_PREFIX@@/${CLUSTER_PREFIX}/g" \
  -e "s/@@CLUSTER_PRIMARY_REGION@@/${PRIMARY_REGION}/g" \
  -e "s/@@CLUSTER_SECONDARY_REGION@@/${SECONDARY_REGION}/g" \
  -e "s/@@CLUSTER_DB_SIZE@@/${CLUSTER_DB_SIZE}/g" \
  -e "s/@@CLUSTER_PGBENCH_SIZE@@/${CLUSTER_PGBENCH_SIZE}/g" \
  -e "s/@@CLUSTER_MONITOR_SIZE@@/${CLUSTER_MONITOR_SIZE}/g" \
  -e "s/@@K8S_VERSION@@/${K8S_VERSION}/g" \
  ${3} > ${4}
}

if [ -z "$3" ]
then
   usage
fi

K8S_VERSION="${K8S_VERSION:-1.27}"
CLUSTER_PREFIX=$1
CLUSTER_PRIMARY_REGION=$2
CLUSTER_SECONDARY_REGION=$3
CLUSTER_DB_SIZE="${DB_INSTANCE_TYPE:-r5.large}"
CLUSTER_PGBENCH_SIZE="${PGBENCH_INSTANCE_TYPE:-m5.large}"
CLUSTER_MONITOR_SIZE="${MONITOR_INSTANCE_TYPE:-m5.large}"

TOP=$(cd "$(dirname "$0")"; pwd)
WORKDIR=${TOP}/work/${CLUSTER_PREFIX}
TEMPLATES=${TOP}/templates

if [ ! -d ${WORKDIR} ]
then
  mkdir -p ${WORKDIR}/cloudnative-pg
fi

# Create secondary EKS cluster (swap variables)
mangle ${CLUSTER_SECONDARY_REGION} ${CLUSTER_PRIMARY_REGION} ${TEMPLATES}/cluster.yaml.in ${WORKDIR}/${CLUSTER_PREFIX}-${CLUSTER_SECONDARY_REGION}.yaml

# Create primary EKS cluster
mangle ${CLUSTER_PRIMARY_REGION} ${CLUSTER_SECONDARY_REGION} ${TEMPLATES}/cluster.yaml.in ${WORKDIR}/${CLUSTER_PREFIX}-${CLUSTER_PRIMARY_REGION}.yaml

# Create the script for the setup
mangle ${CLUSTER_PRIMARY_REGION} ${CLUSTER_SECONDARY_REGION} ${TEMPLATES}/deploy.sh.in ${WORKDIR}/deploy.sh

# Create the script for tearing down
mangle ${CLUSTER_PRIMARY_REGION} ${CLUSTER_SECONDARY_REGION} ${TEMPLATES}/teardown.sh.in ${WORKDIR}/teardown.sh

chmod +x ${WORKDIR}/*.sh

# Create the README file
mangle ${CLUSTER_PRIMARY_REGION} ${CLUSTER_SECONDARY_REGION} ${TEMPLATES}/README.md.in ${WORKDIR}/README.md

# Manifest for the primary cluster
mangle ${CLUSTER_PRIMARY_REGION} ${CLUSTER_SECONDARY_REGION} ${TEMPLATES}/cnpg-primary.yaml.in ${WORKDIR}/cloudnative-pg/${CLUSTER_PREFIX}-${CLUSTER_PRIMARY_REGION}.yaml
# Manifest for the replica cluster
mangle ${CLUSTER_PRIMARY_REGION} ${CLUSTER_SECONDARY_REGION} ${TEMPLATES}/cnpg-replica.yaml.in ${WORKDIR}/cloudnative-pg/${CLUSTER_PREFIX}-${CLUSTER_SECONDARY_REGION}.yaml

# Manifest for kubestack
curl -s https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml | \
  sed -e 's/#workload/workload/' -e 's/#nodeSelector/nodeSelector/' \
  -e 's/#alerManagerSpec/alertManagerSpec/' -e 's/#alertManagerSpec/alertManagerSpec/' \
  > ${WORKDIR}/cloudnative-pg/kubestack.yaml
