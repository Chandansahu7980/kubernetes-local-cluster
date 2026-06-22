# MySQL StatefulSet with Dynamic PV

This page explains how to deploy a MySQL StatefulSet on Kubernetes using dynamic Persistent Volumes (PV).

## Overview

A StatefulSet is used for stateful applications that require stable network identities and persistent storage. In this guide, we deploy MySQL with:

- dynamic volume provisioning
- a headless service
- stable pod identities
- scaling of StatefulSet replicas

## Prerequisites

Before deploying this StatefulSet, you must have a StorageClass configured for dynamic provisioning. A common setup is using NFS with an NFS client or NFS server provisioner.

> Refer to the `HELM` section in this repository for instructions on creating the StorageClass using `nfs-client` Helm charts.

## Key Concepts

### Headless Service

A headless service is a Kubernetes Service without a cluster IP. It is created by setting `clusterIP: None`.

Why it is required:

- It allows StatefulSet pods to receive stable DNS entries.
- Each pod gets its own DNS record, such as `mysql-0.mysql-headless.default.svc.cluster.local`.
- It enables direct pod-to-pod communication without load balancing.

How it helps stateful applications:

- Stateful applications like MySQL need stable network identity and storage.
- A headless service ensures each pod can be addressed individually.
- This is especially important for database clusters or replication setups.

### StatefulSet Benefits

StatefulSets provide:

- stable Pod names
- stable network identities
- stable storage using PersistentVolumeClaims
- ordered deployment and scaling behavior

## Why Dynamic PV?

Dynamic provisioning automates the creation of PersistentVolumes based on a StorageClass. This avoids manual PV creation and simplifies deployment.

For MySQL StatefulSet, each replica uses its own dynamically provisioned volume.

## How to Scale the StatefulSet

You can scale the StatefulSet by increasing the `replicas` field in the StatefulSet manifest or using `kubectl scale`.

Example:

```bash
kubectl scale statefulset mysql --replicas=3
```

When scaling up:

- Kubernetes creates the next pod in order (`mysql-1`, `mysql-2`, ...).
- Each new pod gets its own PersistentVolumeClaim and dynamically provisioned volume.
- The headless service provides stable DNS names for all pods.

## Recommended Flow

1. Install or configure NFS StorageClass using the Helm instructions in the `HELM` directory.
2. Verify the StorageClass is available.
3. Deploy the MySQL StatefulSet manifest from this directory.
4. Confirm the headless service and pods are running.
5. Scale the StatefulSet as needed.

## Notes

- If you need a storage class example, check `Helm/README.md` or `Helm/StorageClassGuide.md`.
- Ensure your NFS provisioner is healthy before deploying the StatefulSet.
- StatefulSet pods are created and deleted in order, which helps maintain data consistency.
