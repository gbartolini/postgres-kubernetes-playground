# Welcome to my Postgres in Kubernetes playground

In this section you will find examples and information on how to
run Postgres in Kubernetes using [CloudNativePG](https://cloudnative-pg.io).

It is important that you have enough skills in the Kubernetes administration
area. In our experience, having equivalent CKA and/or CKAD skills helps.

## Requirements

In order to proceed with the examples, you need to have successfully installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): the primary command-line tool to manage Kubernetes clusters
- [kind](https://kind.sigs.k8s.io/): a Kubernetes distribution that works inside Docker, creating a new container for each node.

## Setting up the local Kubernetes cluster

Our examples will use a local Kubernetes cluster in Kind made up of 3 worker
nodes.

```console
curl \
  https://raw.githubusercontent.com/gbartolini/postgres-kubernetes-playground/main/kind/3node-kind.yaml \
  --output /tmp/3node-kind.yaml
kind create cluster --config /tmp/3node-kind.yaml
```

Once you are done, you can delete the cluster with:

```console
kind delete cluster
```
