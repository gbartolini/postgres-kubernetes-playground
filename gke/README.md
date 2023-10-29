# GKE cluster for CloudNativePG demonstrations

This folder contains the `create-gke-cluster.sh` script that helps you
generate a set of files for the creation of:

- 1 GKE cluster with 3 AZ
- 1 bucket, writable in the local region
- 6 worker nodes in each region:
    - 3 for Postgres
    - 3 for pgbench and Prometheus/Grafana

The script generates:

- a wrapper script to be run to generate the clusters using the above configuration

## Requirements

gcloud CLI with enough permissions to create the above in the GKE cluster.

## Example

This example creates an GKE cluster with prefix `jeeg` in `us-central1`.

```bash
./create-gke-cluster.sh jeeg us-central1
```

It will generate the files in the `work/jeeg` folder, including the
instructions in the `work/jeeg/README.md` file.

The final output example is in the `examples/jeeg` folder.

## Instance types

You can specify a different instance type for the database, and for the
remaining workloads by using the environment variables in this example:

```bash
CLUSTER_DB_SIZE=n2-highmem-2 CLUSTER_PGBENCH_SIZE=n2-standard-2 \
./create-gke-cluster.sh jeeg us-central1
```

## Ackwnowledgments

Without the help of my friends, colleagues and fellow contributors of
CloudNativePG I would not have been able to set this up, in particular: Marco
Nenciarini, Leonardo Cecchi and Valerio Del Sarto. Thank you.
