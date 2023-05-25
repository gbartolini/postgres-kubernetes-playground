# CloudNativePG demonstration cluster in EKS

In this folder you will find details on how to create a very simple playground
for CloudNativePG spread across 2 regions:

- Primary EKS cluster  : `jeeg-eu-central-1` (region: `eu-central-1`)
- Secondary EKS cluster: `jeeg-eu-west-1` (region: `eu-west-1`)

Each EKS cluster has:

- 3 worker nodes for Postgres, in 3 different availability zones (with label `workload=postgres`)
- 1 worker nodes for Prometheus and Grafana (with label `workload=monitor`)
- 1 worker nodes for `pgbench` (with label `workload=pgbench`)

There's also an S3 bucket for base backups and the WAL archive in each region:
each object store is writable by the local cluster, and can be read by the
other one (this is needed to demonstrate a replica cluster in the other region
that only uses the object store to be synchronized).

> **IMPORTANT:** the EKS clusters created as part of this playground are
> intended to be disposable and should not be used in production environments.

## Prerequisites

- [AWS Command Line Interface](https://aws.amazon.com/cli/) correctly
installed in your system
- Enough privileges to create resources in EKS

## How to deploy the playground

Once you have ensured access to AWS is working, run:

    ./deploy.sh

Then wait (this can take between 30 minutes to an hour).

At this point, you should have the two EKS clusters and the object stores
properly set up. Make sure the nodes are up and running and the labels
are correctly set, as explained in the next section.

## Verify EKS nodes

To start with, verify that all the nodes you need are in the `eu-central-1` region cluster.

First, switch `kubectl` to jeeg-eu-central-1 (save this command!):

    aws eks update-kubeconfig --region eu-central-1 --name jeeg-eu-central-1

Then run:

    kubectl get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type,workload

You should get something similar to this:

    NAME                                             STATUS   ROLES    AGE  VERSION               ZONE            INSTANCE-TYPE   WORKLOAD
    ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.26.4-eks-VVVVVVV   eu-central-1c   r5.large        postgres
    ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.26.4-eks-VVVVVVV   eu-central-1a   m5.large        pgbench
    ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.26.4-eks-VVVVVVV   eu-central-1a   r5.large        postgres
    ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.26.4-eks-VVVVVVV   eu-central-1a   m5.large        monitor
    ip-192-168-XX-XX.eu-central-1.compute.internal   Ready    <none>   1m   v1.26.4-eks-VVVVVVV   eu-central-1b   r5.large        postgres

Now, switch `kubectl` to the jeeg-eu-west-1 cluster (save this too!):

    aws eks update-kubeconfig --region eu-west-1 --name jeeg-eu-west-1

and run again:

    kubectl get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type,workload

## How to retrieve the ARN for IRSA (required by backups)

> **IMPORTANT:** This section is critical to setup the backup infrastructure
> for both regions, so you need to pay careful attention to this.

[CloudNativePG supports IRSA](https://cloudnative-pg.io/documentation/current/backup_recovery/#iam-role-for-service-account-irsa),
which stands for "IAM Role for Service Account", to authorize access to an
object store using the workload identity of a running Postgres cluster, without
having to provide any credentials, as describe in the

The main idea is that the Postgres cluster in `jeeg-eu-central-1`
needs to write in the local `jeeg-eu-central-1` S3
bucket, and (potentially) to read from the `jeeg-eu-west-1` bucket.

Symmetrically, the Postgres cluster in `jeeg-eu-west-1` (which starts as a replica cluster) needs to write in the local `jeeg-eu-west-1` S3
bucket, and (at least initially) to read from the `jeeg-eu-central-1` bucket.

You can retrieve the ARNs to set workload identity authorization with the
respective S3 buckets for WAL archiving and backup with:

    eksctl --region eu-central-1 --cluster jeeg-eu-central-1 get iamserviceaccount jeeg-eu-central-1 -o json | jq '.[0].status.roleARN'
    eksctl --region eu-west-1 --cluster jeeg-eu-west-1 get iamserviceaccount jeeg-eu-west-1 -o json | jq '.[0].status.roleARN'

### There's more ...

IRSA allows us to set this permission in a IAM service account that we can
later specify in the CloudNativePG `cluster` definition. Specifically, each IAM
has the following permissions in the local object store:

- `s3:AbortMultipartUpload`
- `s3:DeleteObject`
- `s3:GetObject`
- `s3:ListBucket`
- `s3:PutObject`
- `s3:PutObjectTagging`

At the same time, it has the following read-only permissions for the S3 bucket
in the other region:

- `s3:GetObject`
- `s3:ListBucket`

## How to tear down the playground

To permanently delete the playground, run:

    ./teardown.sh

## Enjoy CloudNativePG

You now have two separate Kubernetes clusters. The `cloudnative-pg` folder
contains two manifest files:

- `jeeg-eu-central-1.yaml`: for the initial primary
  cluster
- `jeeg-eu-west-1.yaml`: for the initial
  replica cluster

Make sure you properly set the ARN in each of them before you start.

> **IMPORTANT:** Should you create and destroy the Postgres clusters multiple
> times, make sure that the object stores are empty, as CloudNativePG prevents
> you from writing WAL files on a non-empty bucket.

### Installing the operator

You can install the operator using the instructions you find in the
[CloudNativePG documentation](https://cloudnative-pg.io/documentation/current/installation_upgrade/#directly-using-the-operator-manifest).

### Installing Prometheus and Grafana

You can install Prometheus and Grafana by following the instructions provided in
["Quickstart: Part 4 - Monitor clusters with Prometheus and Grafana"](https://cloudnative-pg.io/documentation/current/quickstart/#part-4-monitor-clusters-with-prometheus-and-grafana).

Make sure that you deploy them in the node with label `workload=monitor` by
uncommenting the `nodeSelector` stanzas in the
[kube-stack-config.yaml](https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml)
file, as follows:

```
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

## Accessing the S3 buckets

You can access the content of the buckets using the
[`aws s3` command line interface](https://docs.aws.amazon.com/cli/latest/userguide/cli-services-s3-commands.html).

To access the bucket in the primary `eu-central-1` region, type:

```
    aws s3 ls --recursive jeeg-eu-central-1
```

To access the bucket in the secondary `eu-west-1` region, type:

```
    aws s3 ls --recursive jeeg-eu-west-1
```

## Running pgbench

You can run `pgbench` with the default OLTP-like benchmark only on a Postgres
primary. First you need to initialize it as follows:

    kubectl cnpg pgbench \
      --dry-run \
      --db-name pgbench \
      --job-name pgbench-init \
      --node-selector workload=pgbench \
      jeeg-eu-central-1 \
      -- --initialize --scale '100'

Then, you can run a benchmark like the very simple one here:

    kubectl cnpg pgbench \
      --dry-run \
      --db-name pgbench \
      --job-name pgbench-run \
      --node-selector workload=pgbench \
      jeeg-eu-central-1 \
      -- --time 30 --client 1 --jobs 1

## Notes

This file and the other ones in the `jeeg` folder have been automatically
generated by [`create-eks-cluster.sh`](https://github.com/gbartolini/postgres-kubernetes-playground/blob/main/aws-eks/create-eks-cluster.sh) as follows:

This example creates an EKS cluster with prefix `jeeg` in `eu-central-1` and `eu-west-1`:

```bash
./create-eks-cluster.sh jeeg eu-central-1 eu-west-1
```
