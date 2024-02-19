# CloudNativePG Benchmarking Documentation

Welcome to the CloudNativePG benchmarking guide! This documentation outlines
the process of experimenting with multiple volumes in PostgreSQL using
CloudNativePG. With the recent introduction of declarative tablespaces in
version 1.22, CloudNativePG now fully supports multiple volumes in PostgreSQL,
offering increased flexibility and scalability.

## Supported Volumes

CloudNativePG supports the following volumes:

- Main `PGDATA` volume
- Dedicated [WAL volume](https://cloudnative-pg.io/documentation/current/storage/#volume-for-wal)
- Arbitrary volumes for individual [PostgreSQL tablespaces](https://cloudnative-pg.io/documentation/current/tablespaces/) (including temporary tablespaces)

## Benchmarking Guidelines

To conduct benchmarks in your environment using your storage classes, consider
the following steps:

1. Run tests with an increasing number of volumes:
   - Instance with a single volume (`PGDATA` only)
   - Instance with a dedicated WAL volume
   - Instance with a tablespace for data and a tablespace for indexes
   - Instance with 8 tablespaces, with tables partitioned by hash (8 partitions)

2. Ensure that your tests cover single replica volumes, as we recommend relying on
   [Postgres replication](https://cloudnative-pg.io/documentation/current/architecture/#synchronizing-the-state) rather than storage replication.

3. Share your results with us, as we plan to incorporate findings into a talk at KubeCon Europe in March 2024.

## Kubernetes Environment Note

The benchmarking environment used for these tests was generated using the
[AWK-AKS demo](https://github.com/gbartolini/postgres-kubernetes-playground/tree/main/aws-eks)
presented at KubeCon NA in November 2023. Tests were conducted on Amazon EKS,
utilizing the `r5.large` (16GB) and `r5.4xlarge` (128GB) instances and the
`ebs-sc` storage class. Manifests provided reflect these configurations; adjust
them based on your storage class and available CPU/Memory resources.

## Before You Begin

Ensure you have:

- Installed the latest version of the CloudNativePG operator [following the instructions](https://cloudnative-pg.io/documentation/current/installation_upgrade/).
- Installed the [kubectl cnpg plugin](https://cloudnative-pg.io/documentation/current/kubectl-plugin/).

## General Test Procedure

The general test procedure involves:

1. Deploying the PostgreSQL `Cluster` resource using a specific test manifest.
2. Running the initialization process of `pgbench` with desired scale.
3. Running `pgbench` OLTP-like processes for a given time, collecting relevant metrics.

## Example Tests

### Test #1 - PGDATA Only

Open the [`01-pgdata-only.yaml`](01-pgdata-only.yaml) file and adapt it for
your scope.

Create the `pgdata-only` cluster by running:

```sh
kubectl apply -f 01-pgdata-only.yaml
```

Generate the `pgbench` init job with:

```sh
kubectl cnpg pgbench --dry-run \
  --db-name pgbench \
  --job-name pgbench-init-pgdata-only \
  --node-selector workload=pgbench \
  pgdata-only \
  -- --initialize --scale '4500' | kubectl apply -f -
```

*Note that we should initialize also with larger scales to reduce the risk of
memory caching.*

Then watch the progress with:

```sh
kubectl logs jobs/pgbench-init-pgdata-only pgbench -f
```

With the following output:

```
299900000 of 300000000 tuples (99%) done (elapsed 751.64 s, remaining 0.25 s)
300000000 of 300000000 tuples (100%) done (elapsed 751.74 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 935.63 s (drop tables 0.03 s, create tables 0.01 s, client-side generate 756.06 s, vacuum 0.32 s, primary keys 179.21 s).
```

Then run `pgbench` for 5 minutes:

```sh
kubectl cnpg pgbench --dry-run \
  --db-name pgbench \
  --job-name pgbench-run-pgdata-only \
  --node-selector workload=pgbench \
  pgdata-only \
  -- --time 300 --client 16 --jobs 8 | kubectl apply -f -
```

*Note that the above test simulates 16 concurrent connections to PostgreSQL. You
can run the test with a different number of clients (`--client 8 --jobs 4` for
8 clients).*

Then collect the results:

```sh
kubectl logs jobs/pgbench-run-pgdata-only

pgbench (16.1 (Debian 16.1-1.pgdg110+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 4500
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


### Test #2 - PGDATA and WALs

Repeat the steps using the [`02-pgdata-wal.yaml`](02-pg-data.yaml) file as a
base, adapting to your scope. Also, make sure that you adjust job names
accordingly.

Collect and compare results.

### Test #3 - Data and index tablespaces

Open the [`03-pgbench-tbs.yaml`](03-pgbench-tbs.yaml) file, adapt it for
your scope, and apply it to create the `pgbench-tbs` cluster.

Now, initialize the database with `pgbench` requesting to use the `data`
tablespace for data and the `idx` tablespace for indexes:

```
kubectl cnpg pgbench --dry-run \
  --db-name pgbench \
  --job-name pgbench-init-pgbench-tbs \
  --node-selector workload=pgbench \
  pgbench-tbs \
  -- --initialize --tablespace data --index-tablespace idx --scale '4500' | kubectl apply -f -
```

Once the job completes, you can then run the `pgbench` job as usual, like this:

```
kubectl cnpg pgbench --dry-run \
  --db-name pgbench \
  --job-name pgbench-run-pgbench-tbs \
  --node-selector workload=pgbench \
  pgbench-tbs \
  -- --time 300 --client 16 --jobs 8 | kubectl apply -f -
```

### Test #4 - Tablespaces and 8 partitions

Given that [`pgbench` doesn't yet support partitioning of the history
table](https://commitfest.postgresql.org/47/4679/), and it is not possible to
automatically assign a partition to a given tablespace, I provide a modified
schema of the `pgbench` database to have 8 hash partitions spread on 8
different tablespaces. See: [pgbench-8tbs-schema.sql](pgbench-8tbs-schema.sql).

*NOTE: It is worth noting that partitioning introduces a slight overhead in
PostgreSQL and in smaller databases it might not improve performance.*

Before you create the cluster, make sure that you create the configmap for the
projected volume:

```
kubectl create configmap pgbench-sql --from-file pgbench-8tbs-schema.sql
```

Open the [`04-pgbench-8tbs.yaml`](04-pgbench-8tbs.yaml) file, adapt it for
your scope, and apply it to create the `eight-tbs` cluster.

Connect to the PostgreSQL instance and create the schema, by running:

```
kubectl exec -ti eight-tbs-1 -- psql -f /projected/pgbench-8tbs-schema.sql
```

Then, generate the `pgbench` init job with (note the `--init-steps` and
`--partitions` options):

```
kubectl cnpg pgbench --dry-run \
  --db-name pgbench \
  --job-name pgbench-init-8tbs \
  --node-selector workload=pgbench \
  eight-tbs \
  -- --initialize --init-steps gv --partitions 8 --scale '4500' | kubectl apply -f -
```

Then run the usual `pgbench` job.

## Useful queries

You can run the following queries to get an idea of tables, indexes,
tablespaces, size, etc.

Connect to the `pgbench` database via the `kubectl exec` command on the primary
pod:

```sh
kubectl exec -ti eight-tbs-1 -- psql pgbench
```

### Tables information

```sql
SELECT
  c.relname AS table_name,
  CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'm' THEN 'materialized view' WHEN 'i' THEN 'index' WHEN 'S' THEN 'sequence' WHEN 't' THEN 'TOAST table' WHEN 'f' THEN 'foreign table' WHEN 'p' THEN 'partitioned table' WHEN 'I' THEN 'partitioned index' END AS table_type,
  tbs.spcname as table_tablespace,
  pg_catalog.pg_size_pretty(pg_catalog.pg_table_size(c.oid)) AS table_size
FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_catalog.pg_tablespace tbs ON c.reltablespace = tbs.oid
  LEFT JOIN pg_catalog.pg_index i ON i.indexrelid = c.oid
WHERE c.relkind IN ('r','t','p', '')
  AND n.nspname <> 'pg_catalog'
  AND n.nspname !~ '^pg_toast'
  AND n.nspname <> 'information_schema'
  AND pg_catalog.pg_table_is_visible(c.oid)
ORDER BY 1,2;
```

### Indexes information

```sql
SELECT
  c.relname AS idx_name,
  t.relname as idx_table,
  tbs.spcname as idx_tablespace,
  pg_catalog.pg_size_pretty(pg_catalog.pg_table_size(c.oid)) AS idx_size
FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_catalog.pg_tablespace tbs ON c.reltablespace = tbs.oid
  LEFT JOIN pg_catalog.pg_index i ON i.indexrelid = c.oid
  LEFT JOIN pg_catalog.pg_class t ON i.indrelid = t.oid
WHERE c.relkind IN ('i','I','')
  AND n.nspname <> 'pg_catalog'
  AND n.nspname !~ '^pg_toast'
  AND n.nspname <> 'information_schema'
  AND pg_catalog.pg_table_is_visible(c.oid)
ORDER BY 1,2;
```


## Results

### Database larger than memory

| Author             | Date       | Environment                               | Postgres cores | Postgres memory | pgbench scale | DB size | Clients | Time | TPS #1 | TPS #2 | TPS #3 | TPS #4 |
| -------------------|------------|-------------------------------------------|----------------|-----------------|---------------|---------|---------|------|--------|--------|--------|--------|
| Gabriele Bartolini | 2024-02-14 | EKS                                       | 1.5 (r5.large) | 14GB            | 4500          |    66GB | 4       | 300  |        |   554  |   637  | 1,070  |
| Gabriele Bartolini | 2024-02-14 | EKS                                       | 1.5 (r5.large) | 14GB            | 4500          |    66GB | 8       | 300  |        |   889  | 1,157  | 1,441  |
| Gabriele Bartolini | 2024-02-14 | EKS                                       | 1.5 (r5.large) | 14GB            | 4500          |    66GB | 16      | 300  | 1,109  | 1,272  | 1,476  | 1,403  |
| Gabriele Bartolini | 2024-02-19 | EKS                                       | 1.5 (r5.large) | 14GB            | 45000         |   657GB | 4       | 300  |        |   819  |        |   522  |
| Gabriele Bartolini | 2024-02-19 | EKS                                       | 1.5 (r5.large) | 14GB            | 45000         |   657GB | 8       | 300  |        |   822  |        |   963  |
| Gabriele Bartolini | 2024-02-15 | EKS                                       | 1.5 (r5.large) | 14GB            | 45000         |   657GB | 16      | 300  |        | 1,244  |        | 1,293  |
| Jonathan Battiato  | 2024-02-19 | k3s 1.28.6<br/>on 4 RPi4<br/>SSD+Longhorn | 1.5            |  4GB            | 4500          |    66GB | 16      | 300  | 222    | 218    |        |        |

### Database fitting entirely in memory

| Author             | Date       | Environment                   | Postgres cores  | Postgres memory | pgbench scale | DB size | Clients | Time | TPS #1 | TPS #2 | TPS #3 | TPS #4 |
| -------------------|------------|-------------------------------|-----------------|-----------------|---------------|---------|---------|------|--------|--------|--------|--------|
| Gabriele Bartolini | 2024-02-07 | EKS                           | 14 (r5.4xlarge) | 64GB            | 3000          |    44GB | 16      | 300  | 3,510  | 5,143  | 1,665  | 1,797  |
| Florian Coulombel  | 2024-02-12 | Baremetal v1.29.1<br/>PowerMax| 14              | 64GB            | 3000          |    44GB | 16      | 300  | 8,881  | 8,780  | 7,347  | 8,625  |

## Conclusions

Feel free to adapt these tests based on your specific use case and
requirements. We appreciate your collaboration in sharing your results,
contributing to the collective understanding of CloudNativePG performance.

Happy benchmarking!

Gabriele
