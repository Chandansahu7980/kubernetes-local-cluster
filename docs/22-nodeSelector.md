# Kubernetes NodeSelector

## Overview

In Kubernetes, the Scheduler decides which Node should run a Pod.

By default, the Scheduler considers:

- Available CPU
- Available Memory
- Node Conditions
- Scheduling Policies

If multiple nodes satisfy these requirements, Kubernetes can place the Pod on **any** of them.

However, in real-world environments, some applications should run only on specific nodes.

Examples:

- Database Pods on high-memory servers
- AI/ML workloads on GPU nodes
- Monitoring applications on dedicated monitoring nodes
- SSD workloads on SSD-enabled nodes

To achieve this, Kubernetes provides **NodeSelector**.

---

# Why NodeSelector?

Imagine a cluster with three worker nodes.

| Node | Hardware |
|------|-----------|
| worker1 | SSD + 16 GB RAM |
| worker2 | HDD + 8 GB RAM |
| worker3 | HDD + 4 GB RAM |

You deploy MySQL.

Without any scheduling rules, Kubernetes may place MySQL on **worker3** simply because it has enough free resources.

This is not ideal.

Instead, you want:

```
MySQL
     │
     ▼
worker1
```

NodeSelector allows you to define exactly where a Pod should run.

---

# How NodeSelector Works

NodeSelector works by matching **Node Labels**.

Every Kubernetes node contains labels.

```
Node
 │
 ├── disktype=ssd
 ├── environment=prod
 ├── zone=east
```

A Pod can request one or more labels.

```
Pod

nodeSelector:

disktype: ssd
```

If the labels match, Kubernetes schedules the Pod.

If not, the Pod remains Pending.

---

# NodeSelector Workflow

```
Deployment
       │
       ▼
Scheduler
       │
       ▼
Node Labels Match?
       │
   ┌───┴────┐
   │        │
  Yes       No
   │        │
   ▼        ▼
Running   Pending
```

---

# Node Labels

View all node labels.

```bash
kubectl get nodes --show-labels
```

Or inspect a specific node.

```bash
kubectl describe node worker1
```

Look for:

```
Labels:
```

---

# Adding Labels

Assign labels to nodes.

Worker1:

```bash
kubectl label node worker1 disktype=ssd
```

Worker2:

```bash
kubectl label node worker2 disktype=hdd
```

Worker3:

```bash
kubectl label node worker3 disktype=hdd
```

Verify:

```bash
kubectl get nodes --show-labels
```

Expected:

```
worker1
disktype=ssd

worker2
disktype=hdd

worker3
disktype=hdd
```

---

# Lab 1 – Schedule Pods to SSD Node

Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ssd
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-ssd
  template:
    metadata:
      labels:
        app: nginx-ssd
    spec:
      nodeSelector:
        disktype: ssd

      containers:
      - name: nginx
        image: nginx
```

Deploy:

```bash
kubectl apply -f nginx-ssd.yaml
```

Verify:

```bash
kubectl get pods -o wide
```

Expected:

```
NODE
worker1
worker1
```

---

# Lab 2 – Invalid Label

Change:

```yaml
nodeSelector:
  disktype: nvme
```

Deploy.

Check:

```bash
kubectl get pods
```

Expected:

```
Pending
```

Describe:

```bash
kubectl describe pod <pod-name>
```

Events:

```
didn't match Pod's node affinity/selector
```

This is a common production troubleshooting message.

---

# Removing Labels

Remove:

```bash
kubectl label node worker1 disktype-
```

Verify:

```bash
kubectl get nodes --show-labels
```

---

# Production Example

```
worker1

database=true

worker2

web=true

worker3

monitoring=true
```

Deployments:

MySQL

```yaml
nodeSelector:
  database: "true"
```

PHP

```yaml
nodeSelector:
  web: "true"
```

Grafana

```yaml
nodeSelector:
  monitoring: "true"
```

This ensures each application runs only on its intended node.

---

# NodeSelector vs Taints

| Feature | NodeSelector | Taints |
|----------|--------------|---------|
| Applied On | Pod | Node |
| Uses | Labels | Taints |
| Purpose | Attract Pods | Repel Pods |
| Decision | Pod chooses Node | Node rejects Pods |

Think of it like this:

NodeSelector:
```
Pod
↓
"I want this node."
```

Taints:
```
Node
↓
"I don't want Pods."
```

---

# Limitations of NodeSelector

NodeSelector only supports **exact matching**.

Supported:

```
disktype=ssd
```

Not Supported:

- SSD OR NVMe
- Prefer SSD
- Avoid HDD
- Memory > 8 GB
- Multiple scheduling rules

For these advanced scenarios, Kubernetes provides **Node Affinity**.

---

# Troubleshooting

## Pod Pending

```bash
kubectl describe pod <pod>
```

Common Event:

```
didn't match Pod's node affinity/selector
```

Cause:

Node label does not exist.

---

## Verify Labels

```bash
kubectl get nodes --show-labels
```

---

## Verify Scheduling

```bash
kubectl get pods -o wide
```

---

# Best Practices

- Use meaningful labels.
- Follow consistent naming conventions.
- Avoid too many custom labels.
- Use NodeSelector only for simple scheduling.
- Prefer Node Affinity for complex requirements.

---

# Interview Questions

### What is NodeSelector?

A scheduling mechanism that places Pods on Nodes with matching labels.

---

### Does NodeSelector use Taints?

No.

It uses Node Labels.

---

### What happens if no Node matches?

The Pod remains Pending.

---

### How do you view labels?

```bash
kubectl get nodes --show-labels
```

---

### Can NodeSelector perform OR conditions?

No.

Use Node Affinity instead.

---

# Summary

In this you learned:

- What NodeSelector is
- Why it was introduced
- Node Labels
- Scheduling Pods using labels
- Troubleshooting Pending Pods
- Production use cases
- Best practices
- Interview questions

NodeSelector is simple and easy to use, but it has limitations. In the next chapter, you'll learn **Node Affinity**, which provides advanced scheduling capabilities such as preferred nodes, required rules, multiple label matching, and more.