# CloudNativePG Demonstration Cluster in EKS

This folder contains instructions on creating a simple CloudNativePG playground
spread across two regions:

- **Primary EKS Cluster**: `jeeg-eu-central-1` (Region: `eu-central-1`)
- **Secondary EKS Cluster**: `jeeg-eu-west-1` (Region: `eu-west-1`)

Each EKS cluster includes:

- 3 worker nodes for PostgreSQL in 3 different availability zones (label:
  `workload=postgres`)
- 1 worker node for Prometheus and Grafana (label: `workload=monitor`)
- 1 worker node for `pgbench` (label: `workload=pgbench`)

Additionally, each region has an S3 bucket for base backups and WAL archives.
These object stores are writable by their local clusters and readable by the
other cluster to demonstrate replication using the object store.

> **IMPORTANT:** The EKS clusters created in this playground are disposable and
> should not be used in production environments.

## Prerequisites

- [AWS Command Line Interface](https://aws.amazon.com/cli/) correctly installed
- Sufficient privileges to create resources in EKS

## How to Deploy the Playground

Once AWS access is confirmed, run:

```shell
./deploy.sh
```

This process may take 30 minutes to an hour. After deployment, ensure the nodes
are up and running with the correct labels.

## Verify EKS Nodes

First, verify the nodes in the `eu-central-1` region cluster:

Switch `kubectl` to `jeeg-eu-central-1`:

```shell
aws eks update-kubeconfig --region eu-central-1 --name jeeg-eu-central-1
```

Then run:

```shell
kubectl get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type,workload
```

You should see output similar to this:

```shell
NAME                                            STATUS   ROLES    AGE  VERSION               ZONE            INSTANCE-TYPE   WORKLOAD
ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.29.5-eks-VVVVVVV   eu-central-1c   r5.large        postgres
ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.29.5-eks-VVVVVVV   eu-central-1a   m5.large        pgbench
ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.29.5-eks-VVVVVVV   eu-central-1a   r5.large        postgres
ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.29.5-eks-VVVVVVV   eu-central-1a   m5.large        monitor
ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.29.5-eks-VVVVVVV   eu-central-1b   r5.large        postgres
```

Next, switch `kubectl` to the `jeeg-eu-west-1`
cluster:

```shell
aws eks update-kubeconfig --region eu-west-1 --name jeeg-eu-west-1
```

And run again:

```shell
kubectl get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type,workload
```

## Retrieve the ARN for IRSA (Required for Backups)

> **IMPORTANT:** This section is critical for setting up the backup
> infrastructure in both regions.

CloudNativePG supports IRSA (IAM Role for Service Account), allowing access to
an object store using the workload identity of a running PostgreSQL cluster
without credentials.

To authorise access to the S3 buckets for WAL archiving and backup:

```shell
eksctl --region eu-central-1 --cluster jeeg-eu-central-1 get iamserviceaccount jeeg-eu-central-1 -o json | jq '.[0].status.roleARN'
eksctl --region eu-west-1 --cluster jeeg-eu-west-1 get iamserviceaccount jeeg-eu-west-1 -o json | jq '.[0].status.roleARN'
```

### IRSA Permissions

Each IAM service account has the following permissions in the local object
store:

- `s3:AbortMultipartUpload`
- `s3:DeleteObject`
- `s3:GetObject`
- `s3:ListBucket`
- `s3:PutObject`
- `s3:PutObjectTagging`

For the remote object store, the permissions are:

- `s3:GetObject`
- `s3:ListBucket`

## How to Tear Down the Playground

To delete the playground, run:

```shell
./teardown.sh
```

## Volume Snapshots

To use volume snapshots, follow the instructions in the
[AWS EBS CSI driver project](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes/snapshot).

The deployment script installs the necessary components:

```bash
kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter//client/config/crd | kubectl apply -f -
kubectl -n kube-system kustomize https://github.com/kubernetes-csi/external-snapshotter//deploy/kubernetes/snapshot-controller | kubectl apply -f -
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/snapshot/manifests/classes/snapshotclass.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/snapshot/manifests/classes/storageclass.yaml
```

Use the `ebs-sc` storage class for PostgreSQL volumes.

## Enjoy CloudNativePG

You now have two separate Kubernetes clusters. The `cloudnative-pg` folder
contains two manifest files:

- `jeeg-eu-central-1.yaml`: Initial primary cluster
- `jeeg-eu-west-1.yaml`: Initial replica cluster

Ensure you set the ARN correctly in each file before starting.

> **IMPORTANT:** If you recreate and destroy the PostgreSQL clusters multiple
> times, ensure the object stores are empty, as CloudNativePG prevents writing
> WAL files to a non-empty bucket.

### Installing the Operator

Follow the
[CloudNativePG documentation](https://cloudnative-pg.io/documentation/current/installation_upgrade/#directly-using-the-operator-manifest)
to install the operator.

### Installing Prometheus and Grafana

Follow ["Quickstart: Part 4 - Monitor clusters with Prometheus and Grafana"](https://cloudnative-pg.io/documentation/current/quickstart/#part-4-monitor-clusters-with-prometheus-and-grafana)
for instructions. Ensure deployment on the node with label `workload=monitor`
by uncommenting the `nodeSelector` stanzas in the
[kube-stack-config.yaml](https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml)
file:

```yaml
nodeSelector:
  workload: monitor
prometheus:
  ...
  nodeSelector:
    workload: monitor
grafana:
  ...
  nodeSelector:
    workload: monitor
alertmanager:
  ...
  alertManagerSpec:
    nodeSelector:
      workload: monitor
```

Then, run:

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install -f cloudnative-pg/kubestack.yaml prometheus-community prometheus-community/kube-prometheus-stack
```

## Accessing the S3 Buckets

To access the primary region bucket:

```shell
aws s3 ls --recursive jeeg-eu-central-1
```

To access the secondary region bucket:

```shell
aws s3 ls --recursive jeeg-eu-west-1
```

## Running pgbench

Initialise `pgbench`:

```shell
kubectl cnpg pgbench --dry-run --db-name pgbench --job-name pgbench-init --node-selector workload=pgbench jeeg-eu-central-1 -- --initialize --scale '100'
```

Run a simple benchmark:

```shell
kubectl cnpg pgbench --dry-run --db-name pgbench --job-name pgbench-run --node-selector workload=pgbench jeeg-eu-central-1 -- --time 30 --client 1 --jobs 1
```

## Simulating a Data Center Switchover

### Demoting the Primary Cluster

To simulate a data centre switchover, demote the primary cluster by modifying
its configuration. Change the `replica` setting from `false` to `true`:

```yaml
replica:
  enabled: false
```

to:

```yaml
replica:
  enabled: true
```

This change will configure the `jeeg-eu-central-1`
cluster to become a replica of the
`jeeg-eu-west-1` cluster, synchronizing by
retrieving new WAL files from the remote object store.

### Promoting the Secondary Cluster

After demoting the primary cluster, promote the secondary cluster by setting
`replica.enabled` to `false`:

```yaml
replica:
  enabled: true
```

to:

```yaml
replica:
  enabled: false
```

This adjustment allows the `jeeg-eu-west-1`
cluster to take over read-write operations and start pushing WAL files to the
S3 buckets. These WAL files will then be consumed by the
`jeeg-eu-central-1` replica cluster.

## Notes

The scripts and files in the `jeeg` folder were automatically
generated by the
[`create-eks-cluster.sh`](https://github.com/gbartolini/postgres-kubernetes-playground/blob/main/aws-eks/create-eks-cluster.sh)
script.

To create an EKS cluster with the specified prefix and regions, use:

```bash
./create-eks-cluster.sh jeeg eu-central-1 eu-west-1
```
