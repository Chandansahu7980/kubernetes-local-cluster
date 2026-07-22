# DaemonSet in Kubernetes

A DaemonSet is a Kubernetes workload object that ensures a copy of a specific pod runs on every single node (or a targeted subset of nodes) in your cluster.

---

# Why Was DaemonSet Introduced?

Suppose you have a Kubernetes cluster.

```
Master

Worker1

Worker2
```

Now imagine you install **Prometheus Node Exporter**.

Its purpose is to collect:

- CPU Usage
- Memory Usage
- Disk Usage
- Network Statistics

Question:

How many Pods should run?

Not:

```
replicas: 2
```

Not:

```
replicas: 5
```

Instead, you need:

> **One Pod running on every node.**

As your cluster grows, new nodes should automatically receive a Node Exporter Pod.

This is exactly why **DaemonSets** were introduced.

---

# What is a DaemonSet?

A **DaemonSet** ensures that **one copy of a Pod runs on every eligible node** in the cluster.

Whenever:

- A new node joins
- A node is removed
- Node labels change

The DaemonSet controller automatically reconciles the cluster and creates or removes Pods as needed.

Unlike a Deployment, you **do not specify replicas**.

---

# Deployment vs StatefulSet vs DaemonSet

| Feature | Deployment | StatefulSet | DaemonSet |
|----------|------------|-------------|------------|
| Purpose | Stateless Applications | Stateful Applications | Node-level Services |
| Uses Replicas | ✅ | ✅ | ❌ |
| Stable Identity | ❌ | ✅ | ❌ |
| Stable Storage | ❌ | ✅ | Usually Not Required |
| Auto Runs on New Nodes | ❌ | ❌ | ✅ |
| Common Examples | Nginx, APIs | MySQL, PostgreSQL | Node Exporter, Fluent Bit |

---

# How DaemonSet Works

Deployment says:

> Run 3 Pods.

DaemonSet says:

> Run one Pod on every eligible node.

If the control-plane node has a `NoSchedule` taint and no matching toleration, only the worker nodes will receive Pods.

---

# DaemonSet Architecture

```
                 DaemonSet Controller
                         │
         ┌───────────────┼───────────────┐
         │               │               │
      Master          Worker1         Worker2
         │               │               │
     Node Pod        Node Pod        Node Pod
```

The DaemonSet controller continuously watches the cluster and maintains one Pod on every eligible node.

---

# DaemonSet Controller

The DaemonSet controller continuously performs:

```
List Nodes
↓
Check Eligibility
↓
Need New Pod?
↓
Create Pod
↓
Node Removed?
↓
Delete Pod
↓
Repeat
```

This process is called the **Reconciliation Loop**.

---

# Basic DaemonSet YAML

```yaml
apiVersion: apps/v1
kind: DaemonSet

metadata:
  name: nginx-daemonset
  namespace: daemonset-lab

spec:
  selector:
    matchLabels:
      app: nginx-daemon

  template:
    metadata:
      labels:
        app: nginx-daemon

    spec:
      containers:
      - name: nginx
        image: nginx:latest
```

Notice:

There is **no replicas field**.

---

# Hands-on Lab 1 - Create Your First DaemonSet

Apply:

```bash
kubectl apply -f nginx-daemonset.yaml
```

Verify:

```bash
kubectl get daemonset -n daemonset-lab
```

Expected:

```
NAME              DESIRED   CURRENT   READY

nginx-daemonset      2         2         2
```

Verify Pod placement:

```bash
kubectl get pods -o wide -n daemonset-lab
```

Expected:

```
worker1

worker2
```

One Pod per worker node.

---

# Node Selection

Sometimes you don't want Pods on every node.

Example:

Only SSD nodes.

```yaml
nodeSelector:
  disktype: ssd
```

Now only nodes with:

```
disktype=ssd
```

will receive DaemonSet Pods.

---

# Hands-on Lab 2 - Node Selector

Modify:

```yaml
spec:
  template:
    spec:

      nodeSelector:
        disktype: ssd
```

Deploy:

```bash
kubectl apply -f nginx-daemonset.yaml
```

Verify:

```bash
kubectl get pods -o wide -n daemonset-lab
```

Only the SSD node should run the Pod.

---

# DaemonSet and Taints

Your control-plane node has:

```
node-role.kubernetes.io/control-plane:NoSchedule
```

Without a toleration, DaemonSet Pods will **not** run there.

---

# Tolerations

Add:

```yaml
tolerations:
- key: "node-role.kubernetes.io/control-plane"
  operator: Exists
  effect: NoSchedule
```

Now the DaemonSet can run on the control-plane node.

---

# Hands-on Lab 3 - Taints & Tolerations

Update the DaemonSet YAML with the toleration.

Apply:

```bash
kubectl apply -f nginx-daemonset.yaml
```

Verify:

```bash
kubectl get pods -o wide -n daemonset-lab
```

Expected:

```
Master

Worker1

Worker2
```

One Pod on every node.

---

# Rolling Updates

DaemonSets also support Rolling Updates.

Update:

```yaml
image: nginx:latest
```

to

```yaml
image: nginx:1.27
```

Apply:

```bash
kubectl apply -f nginx-daemonset.yaml
```

Watch rollout:

```bash
kubectl rollout status daemonset/nginx-daemonset -n daemonset-lab
```

---

# Update Strategy

Default:

```yaml
updateStrategy:
  type: RollingUpdate
```

Customize:

```yaml
updateStrategy:
  type: RollingUpdate

  rollingUpdate:
    maxUnavailable: 1
```

Meaning:

Only one DaemonSet Pod can be unavailable during an update.

---

# Hands-on Lab 4 - Rolling Update

Change image version:

```yaml
nginx:latest

↓

nginx:1.27
```

Watch:

```bash
kubectl get pods -w -n daemonset-lab
```

Observe Pods updating one node at a time.

---

# DaemonSet Lifecycle

### New Node Added

```
Worker3 joins

↓

DaemonSet notices

↓

Pod created automatically
```

No manual intervention required.

---

### Node Removed

```
Worker2 removed

↓

DaemonSet Pod disappears

↓

No replacement elsewhere
```

DaemonSets maintain **one Pod per node**, not a fixed number of replicas.

---

### DaemonSet Deleted

Delete:

```bash
kubectl delete daemonset nginx-daemonset -n daemonset-lab
```

Result:

All DaemonSet Pods are automatically deleted because they are owned by the DaemonSet.

---

# Hands-on Lab 5 - Lifecycle

Delete the DaemonSet.

Verify:

```bash
kubectl get ds -n daemonset-lab

kubectl get pods -n daemonset-lab
```

Expected:

```
No resources found.
```

---

# Real-World Use Cases

DaemonSets are commonly used for:

- Prometheus Node Exporter
- Fluent Bit
- Filebeat
- Calico
- Cilium
- kube-proxy
- Falco
- Node Problem Detector
- Security Agents
- Log Collection Agents

Notice that all of these perform **node-level operations**, making DaemonSet the ideal controller.

---

# Useful Commands

View DaemonSets:

```bash
kubectl get daemonsets -A
```

Describe a DaemonSet:

```bash
kubectl describe daemonset <daemonset-name> -n <namespace>
```

View Pods:

```bash
kubectl get pods -o wide -n daemonset-lab
```

Watch rollout:

```bash
kubectl rollout status daemonset/nginx-daemonset -n daemonset-lab
```

Delete:

```bash
kubectl delete daemonset nginx-daemonset -n daemonset-lab
```

---

# Common Issues

## DaemonSet Pod Not Created

### Cause

Node does not match the `nodeSelector` or Node Affinity.

### Verify

```bash
kubectl get nodes --show-labels
```

---

## DaemonSet Not Running on Master

### Cause

Control-plane node has a `NoSchedule` taint.

### Verify

```bash
kubectl describe node master
```

### Fix

Add the appropriate toleration to the DaemonSet.

---

## Pod Stuck in Pending

### Cause

- Insufficient resources
- Taints not tolerated
- Node selector mismatch

### Verify

```bash
kubectl describe pod <pod-name>
```

---

## Rolling Update Stuck

Check rollout:

```bash
kubectl rollout status daemonset/nginx-daemonset -n daemonset-lab
```

Describe the DaemonSet:

```bash
kubectl describe daemonset nginx-daemonset -n daemonset-lab
```

---

# Best Practices

- Use DaemonSets only for node-level services.
- Combine with Node Selector or Node Affinity when targeting specific nodes.
- Use Tolerations if Pods must run on control-plane nodes.
- Use Rolling Updates for safe upgrades.
- Monitor DaemonSet health regularly.
- Avoid using DaemonSets for application workloads.

---

# Interview Questions

### What is a DaemonSet?

A DaemonSet ensures that one copy of a Pod runs on every eligible node in the cluster.

---

### Difference between Deployment and DaemonSet?

Deployment maintains a fixed number of replicas.

DaemonSet maintains one Pod per eligible node.

---

### Does a DaemonSet require replicas?

No.

The DaemonSet controller automatically determines how many Pods are required based on the number of eligible nodes.

---

### Why is Node Exporter deployed as a DaemonSet?

Because every node requires its own monitoring agent to collect CPU, memory, disk, and network metrics.

---

### What happens when a new node joins the cluster?

The DaemonSet controller automatically creates a new Pod on the new node if it matches the scheduling rules.

---

### What happens when a node is removed?

The Pod on that node disappears along with the node. It is **not** recreated on another node.

---

### Can DaemonSets use Taints and Tolerations?

Yes.

They fully support Taints, Tolerations, Node Selectors, and Node Affinity.

---

### Do DaemonSets support Rolling Updates?

Yes.

By default, DaemonSets use the **RollingUpdate** strategy, updating Pods node by node.

---

DaemonSets are the preferred Kubernetes controller for running **node-level services**. They automatically ensure that every eligible node runs exactly one Pod, making them ideal for monitoring, logging, networking, and security agents in production clusters.