# EKS cluster for CloudNativePG demonstrations

This folder contains the `create-eks-cluster.sh` script that helps you
generate a set of files for the creation of:

- 2 EKS clusters
- each cluster in a separate region (primary and secondary), each region
  requiring 3 AZ
- 2 buckets, one per region, writable in the local region and readable from the
  remote one
- 5 worker nodes in each region:
    - 3 for Postgres
    - 1 for pgbench
    - 1 for Prometheus/Grafana

The script generates:

- a YAML file per each EKS cluster
- a wrapper script to be run to generate the clusters using the above configuration

## Requirements

AWS CLI with enough permissions to create the above in the EKS cluster.

## Example

This example creates an EKS cluster with prefix `jeeg` in `eu-central-1` and `eu-west-1`:

```bash
./create-eks-cluster.sh jeeg eu-central-1 eu-west-1
```

It will generate the files in the `work/jeeg` folder, including the
instructions in the `work/jeeg/README.md` file.

The final output example is in the `examples/jeeg` folder.

## Instance types

You can specify a different instance type for the database, for pgbench and for
monitoring by using the environment variables in this example:

```bash
DB_INSTANCE_TYPE=r5.4xlarge PGBENCH_INSTANCE_TYPE=m5.2xlarge MONITOR_INSTANCE_TYPE=m5.2xlarge \
  ./create-eks-cluster.sh cnpg eu-central-1 eu-west-1
```

## Ackwnowledgments

Without the help of my friends, colleagues and fellow contributors of
CloudNativePG I would not have been able to set this up, in particular: Marco
Nenciarini, Leonardo Cecchi and Valerio Del Sarto. Thank you.

