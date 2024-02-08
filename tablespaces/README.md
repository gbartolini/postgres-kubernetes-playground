# Experimenting with multiple volumes in Postgres with CloudNativePG

With the introduction of declarative tablespaces in version 1.22, CloudNativePG
now provides full support for multiple volumes in PostgreSQL through:

- main `PGDATA` volume
- dedicated [volume for Write-Ahead Logs (WALs)](https://cloudnative-pg.io/documentation/current/storage/#volume-for-wal)
- arbitrary number of volumes, each dedicated to a single [PostgreSQL tablespace](https://cloudnative-pg.io/documentation/current/tablespaces/)
  (including for [temporary purposes](https://cloudnative-pg.io/documentation/current/tablespaces/#temporary-tablespaces))

This page provides some guidelines on how to perform some benchmarks on your
environment, using your own storage classes.
**Remember:** our advice is to just rely on
[Postgres replication instead of storage replication](https://cloudnative-pg.io/documentation/current/architecture/#synchronizing-the-state),
so make sure that your tests also cover single replica volumes.

The recommendation is to run a series of tests with an increasing number of
volumes:

1. instance with a single volume (`PGDATA` only)
2. instance with a dedicated WAL volume 
3. instance with a tablespace for data and a tablespace for indexes
4. instance with 8 tablespaces, with tables partitioned by hash (8 partitions)

If your Kubernetes system is properly configured, your benchmarks
should highlight vertical scalability on the I/O level.

Please share your results with me. I am planning to use the findings from this
project in my talk at KubeCon Europe in Paris in March 2024.

## A note about the Kubernetes environment

I have been reusing a cluster generated using the [AWK-AKS demo](https://github.com/gbartolini/postgres-kubernetes-playground/tree/main/aws-eks) I created for my KubeCon NA talk in Chicago in November 2023. I have used this also to write this blog article about [volume snapshot backup](https://www.enterprisedb.com/postgresql-disaster-recovery-with-kubernetes-volume-snapshots-using-cloudnativepg).

In this specific case, I have been running tests on Amazon EKS dedicating a
`r5.4xlarge` and the `ebs-sc` storage class (supporting volume snapshots) for
the PostgreSQL instances. As a result, the manifests reflect these
configurations. Make sure that you adapt the `Cluster` manifests based on your
storage class and the available CPU/Memory resources.

For `pgbench`, I have reserved an `m5.2xlarge` instance.

Before you run any test, please
[install the latest available version of the operator](https://cloudnative-pg.io/documentation/current/installation_upgrade/),
as well as the [kubectl cnpg plugin](https://cloudnative-pg.io/documentation/current/kubectl-plugin/).

## General test procedure

The general scheme of a test is the following:

- deploy the PostgreSQL `Cluster` resource using the specific test manifest
- run the initialization process of `pgbench` with the desired scale, making sure you collect:
    - the overall time of initialization (in the job log)
    - the size of the database (just connect to the instance with `psql` and type `l+`)
- run `pgbench` OLTP-like process for a given amount of time (start with 300
  seconds to validate the solution, then raise it), making sure you collect the output of the `pgbench` job (in particular the number of TPS).

In these tests I use a scale of `3000` for pgbench, which produces a database
of roughly 44GB. Start with this or a smaller value first, and when you are
sure the procedure works, feel free to raise the number.

## Test #1 - PGDATA Only

Create the `pgdata-only` cluster by running:

```bash
kubectl apply -f 01-pgdata-only.yaml
```

Generate the `pgbench` init job with:

```bash
kubectl cnpg pgbench --dry-run \
  --db-name pgbench \
  --job-name pgbench-init-pgdata-only \
  --node-selector workload=pgbench \
  pgdata-only \
  -- --initialize --fillfactor '80' --scale '3000' | kubectl apply -f -
```

Then watch the progress with:

```bash
kubectl logs jobs/pgbench-init-pgdata-only pgbench  -f
```

With the following output:

```console
299900000 of 300000000 tuples (99%) done (elapsed 751.64 s, remaining 0.25 s)
300000000 of 300000000 tuples (100%) done (elapsed 751.74 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 935.63 s (drop tables 0.03 s, create tables 0.01 s, client-side generate 756.06 s, vacuum 0.32 s, primary keys 179.21 s).
```

Then run `pgbench` for 5 minutes:

```bash
kubectl cnpg pgbench --dry-run \
  --db-name pgbench \
  --job-name pgbench-run-pgdata-only \
  --node-selector workload=pgbench \
  pgdata-only \
  -- --time 300 --client 16 --jobs 8 | kubectl apply -f -
```

And watch the progress with:

```bash
kubectl logs jobs/pgbench-run-pgdata-only  -f
``` 

The final output is similar to:

```console
pgbench (16.1 (Debian 16.1-1.pgdg110+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 3000
query mode: simple
number of clients: 16
number of threads: 8
maximum number of tries: 1
duration: 300 s
number of transactions actually processed: 1052993
number of failed transactions: 0 (0.000%)
latency average = 4.558 ms
initial connection time = 33.269 ms
tps = 3510.198652 (without initial connection time)
```

Destroy the cluster.

## Test #2 - PGDATA and WALs

Repeat the same steps on a cluster created using the `02-pgdata-wal.yaml` file
as a source, and by changing the name of `pgbench` jobs.

Collect the results. This is what I got:

```console
pgbench (16.1 (Debian 16.1-1.pgdg110+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 3000
query mode: simple
number of clients: 16
number of threads: 8
maximum number of tries: 1
duration: 300 s
number of transactions actually processed: 1542740
number of failed transactions: 0 (0.000%)
latency average = 3.111 ms
initial connection time = 32.535 ms
tps = 5142.932428 (without initial connection time)
```

The increase in performance in this case is evident.

