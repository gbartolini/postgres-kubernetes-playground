# CloudNativePG examples for KubeCon NA 2022 talk

Welcome to the playground for my
[KubeCon NA 2022 talk with Chris Milsted about "Data On Kubernetes, Deploying And Running PostgresQL And Patterns For Databases In a Kubernetes Cluster"](https://sched.co/182GB).

## Preparing the Kubernetes cluster

The examples in this page assume you have 4 nodes in your Kubernetes cluster,
with a configured default storage class: 3 to run PostgreSQL and one to run
[pgbench](https://www.postgresql.org/docs/current/pgbench.html), a simple
benchmarking tool distributed along Postgres.
Kubernetes can be hosted on premise or in managed clouds, as you prefer.

In my specific case, I am using AWS EKS and have setup labels on each
worker node, as I want to dedicate each node for a specific purpose
(the hostnames below are fictitious):

```console
kubectl label nodes ip-XXX-XXX-XXX-1.eu-central-1.compute.internal workload=postgres
kubectl label nodes ip-XXX-XXX-XXX-2.eu-central-1.compute.internal workload=postgres
kubectl label nodes ip-XXX-XXX-XXX-3.eu-central-1.compute.internal workload=postgres
kubectl label nodes ip-XXX-XXX-XXX-4.eu-central-1.compute.internal workload=pgbench
```

As you can see, nodes are distributed in 3 availability zones:

```console
kubectl get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type,workload
```

returning a similar output:

```console
NAME                                              STATUS   ROLES    AGE   VERSION               ZONE            INSTANCE-TYPE   WORKLOAD
ip-XXX-XXX-XXX-1.eu-central-1.compute.internal    Ready    <none>    1h   v1.23.9-eks-ba74326   eu-central-1c   r5.large        postgres
ip-XXX-XXX-XXX-2.eu-central-1.compute.internal    Ready    <none>    1h   v1.23.9-eks-ba74326   eu-central-1a   r5.large        postgres
ip-XXX-XXX-XXX-3.eu-central-1.compute.internal    Ready    <none>    1h   v1.23.9-eks-ba74326   eu-central-1b   r5.large        postgres
ip-XXX-XXX-XXX-4.eu-central-1.compute.internal    Ready    <none>    1h   v1.23.9-eks-ba74326   eu-central-1a   m5.large        pgbench
```

**IMPORTANT:** you can use any Kubernetes cluster type (as supported by
CloudNativePG), instance type, and storage.

## Installing the operator

In the example, I am using the latest snapshot (unstable) version of the
operator, as I want to test all the new features that are being developed on
the trunk.

```console
kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/artifacts/main/manifests/operator-manifest.yaml
```

Otherwise, you can
[install the latest stable version of the operator](https://cloudnative-pg.io/documentation/current/installation_upgrade/#installation-on-kubernetes)
by following the instructions you find in the CloudNativePG documentation.

## Backup object store

If you want to enable backups, you need to create an object store and make sure
you have a service account that, through an annotation, provides write
permissions on the bucket - we authenticate using IAM roles. The service account
must have the same name as the Postgres cluster you create (in the example
`kubecon-eu-central-1`).

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: <YOUR_ARN>
  name: kubecon-eu-central-1
```

If you do not intend to use backups, please remove the `barmanObjectStore`
configuration from the `kubecon-eu-central-1.yaml` YAML file, as well as the
`ScheduledBackup` resource.

##  Create the cluster

You can create the cluster in the first region with:

```console
kubectl apply -f kubecon-eu-central-1.yaml
```

This will create the cluster with a primary and at least one standby in
synchronous replication. It also sets continuous backup on the S3 bucket you
have configured (if applicable).

You can use the `cnpg` plugin if you want, as follows:

```console
kubectl cnpg status kubecon-eu-central-1
Cluster Summary
Name:               kubecon-eu-central-1
Namespace:          default
System ID:          7153190566668947476
PostgreSQL Image:   ghcr.io/cloudnative-pg/postgresql:15
Primary instance:   kubecon-eu-central-1-1
Status:             Cluster in healthy state
Instances:          3
Ready instances:    3
Current Write LSN:  3/18000000 (Timeline: 1 - WAL File: 00000001000000030000000B)

Certificates Status
Certificate Name                  Expiration Date                Days Left Until Expiration
----------------                  ---------------                --------------------------
kubecon-eu-central-1-ca           2023-01-09 09:47:31 +0000 UTC  89.82
kubecon-eu-central-1-replication  2023-01-09 09:47:31 +0000 UTC  89.82
kubecon-eu-central-1-server       2023-01-09 09:47:31 +0000 UTC  89.82

Continuous Backup status
First Point of Recoverability:  2022-10-11T09:53:39Z
Working WAL archiving:          OK
WALs waiting to be archived:    0
Last Archived WAL:              00000001000000030000000B   @   2022-10-11T14:06:01.792293Z
Last Failed WAL:                -

Streaming Replication status
Name                    Sent LSN    Write LSN   Flush LSN   Replay LSN  Write Lag  Flush Lag  Replay Lag  State      Sync State  Sync Priority
----                    --------    ---------   ---------   ----------  ---------  ---------  ----------  -----      ----------  -------------
kubecon-eu-central-1-2  3/18000000  3/18000000  3/18000000  3/18000000  00:00:00   00:00:00   00:00:00    streaming  quorum      1
kubecon-eu-central-1-3  3/18000000  3/18000000  3/18000000  3/18000000  00:00:00   00:00:00   00:00:00    streaming  quorum      1

Instances status
Name                    Database Size  Current LSN  Replication role  Status  QoS         Manager Version  Node
----                    -------------  -----------  ----------------  ------  ---         ---------------  ----
kubecon-eu-central-1-1  15 GB          3/18000000   Primary           OK      Guaranteed  1.17.1           ip-XXX-XXX-XXX-1.eu-central-1.compute.internal
kubecon-eu-central-1-2  15 GB          3/18000000   Standby (sync)    OK      Guaranteed  1.17.1           ip-XXX-XXX-XXX-2.eu-central-1.compute.internal
kubecon-eu-central-1-3  15 GB          3/18000000   Standby (sync)    OK      Guaranteed  1.17.1           ip-XXX-XXX-XXX-3.eu-central-1.compute.internal
```

## Initialize the benchmark

The provided job for `pgbench-init` will prepare the database for `pgbench` with scale 1000.

```console
kubectl apply -f pgbench-init.yaml
```

Follow the progress with the `logs` command. At the end you can see the size of the database with:

```console
kubectl exec -ti kubecon-eu-central-1-1 postgres -- psql -c '\l+'
```

which should return something similar to:

```console
Defaulted container "postgres" out of: postgres, bootstrap-controller (init)
                                                                              List of databases
   Name    |  Owner   | Encoding | Collate | Ctype | ICU Locale | Locale Provider |   Access privileges   |  Size   | Tablespace |                Description
-----------+----------+----------+---------+-------+------------+-----------------+-----------------------+---------+------------+--------------------------------------------
 app       | app      | UTF8     | C       | C     |            | libc            |                       | 7501 kB | pg_default |
 pgbench   | app      | UTF8     | C       | C     |            | libc            |                       | 15 GB   | pg_default |
 postgres  | postgres | UTF8     | C       | C     |            | libc            |                       | 7501 kB | pg_default | default administrative connection database
 template0 | postgres | UTF8     | C       | C     |            | libc            | =c/postgres          +| 7297 kB | pg_default | unmodifiable empty database
           |          |          |         |       |            |                 | postgres=CTc/postgres |         |            |
 template1 | postgres | UTF8     | C       | C     |            | libc            | =c/postgres          +| 7589 kB | pg_default | default template for new databases
           |          |          |         |       |            |                 | postgres=CTc/postgres |         |            |
(5 rows)
```

In the above example, the `pgbench` database is around `15GB` (scale 1000).

## Run the benchmark

Use the `pgbench.yaml` file to get an idea on how to run `pgbench` in the
created system (on the node with `pgbench` label).

Feel free to change the parameters as you like.

```console
kubectl apply -f pgbench.yaml
```

Results appear in the logs once the job terminates (in the example after 30 seconds):

```console
$ k logs jobs/pgbench
pgbench (15rc2 (Debian 15~rc2-1.pgdg110+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1000
query mode: simple
number of clients: 2
number of threads: 2
maximum number of tries: 3
duration: 30 s
number of transactions actually processed: 4743
number of failed transactions: 0 (0.000%)
number of serialization failures: 0 (0.000%)
number of deadlock failures: 0 (0.000%)
number of transactions retried: 0 (0.000%)
total number of retries: 0
latency average = 12.645 ms
initial connection time = 33.538 ms
tps = 158.170940 (without initial connection time)
statement latencies in milliseconds, failures and retries:
         0.001           0           0  \set aid random(1, 100000 * :scale)
         0.000           0           0  \set bid random(1, 1 * :scale)
         0.000           0           0  \set tid random(1, 10 * :scale)
         0.000           0           0  \set delta random(-5000, 5000)
         0.941           0           0  BEGIN;
         2.726           0           0  UPDATE pgbench_accounts SET abalance = abalance + :delta WHERE aid = :aid;
         1.038           0           0  SELECT abalance FROM pgbench_accounts WHERE aid = :aid;
         1.081           0           0  UPDATE pgbench_tellers SET tbalance = tbalance + :delta WHERE tid = :tid;
         1.096           0           0  UPDATE pgbench_branches SET bbalance = bbalance + :delta WHERE bid = :bid;
         1.038           0           0  INSERT INTO pgbench_history (tid, bid, aid, delta, mtime) VALUES (:tid, :bid, :aid, :delta, CURRENT_TIMESTAMP);
         4.714           0           0  END;
```

You can the retrieve some relevant metrics from `pg_stat_statements` with the
following query in the PostgreSQL database:

```console
kubectl exec -ti kubecon-eu-central-1-1 -- psql -qAt -c \
  "COPY (
  SELECT s.query, s.calls, s.mean_exec_time, s.min_exec_time,
    s.max_exec_time, s.stddev_exec_time, s.rows, s.shared_blks_hit, 
    s.shared_blks_read, s.shared_blks_dirtied, s.shared_blks_written, now() AS ts
  FROM pg_stat_statements s
    JOIN pg_database d ON (d.oid = s.dbid)
    JOIN pg_roles r ON (r.oid = s.userid)
  WHERE d.datname = 'pgbench' AND r.rolname = 'app'
  ORDER BY calls DESC LIMIT 7)
  TO STDOUT WITH (FORMAT CSV, HEADER)"
```

