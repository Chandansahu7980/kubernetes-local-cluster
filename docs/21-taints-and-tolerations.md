# Kubernetes Taints & Tolerations

## Overview

One of Kubernetes' primary responsibilities is deciding **where Pods should run**.
By default, the Kubernetes Scheduler places Pods on any available node that has sufficient CPU and memory resources.
However, in production environments, not every node should run every application.

For example:

- Database workloads should run only on database nodes.
- Monitoring tools should run only on monitoring nodes.
- GPU workloads should run only on GPU-enabled nodes.
- High-memory applications should run on dedicated high-memory servers.

Kubernetes solves this problem using **Taints** and **Tolerations**.

---

# Why Taints & Tolerations Were Introduced

Imagine a Kubernetes cluster with three worker nodes.

```
worker1
worker2
worker3
```

Suppose your organization wants:

| Node | Purpose |
|-------|----------|
| worker1 | MySQL Database |
| worker2 | Web Applications |
| worker3 | Monitoring |

Without restrictions, Kubernetes may schedule Pods like this:

```
worker1
 ├── MySQL
 ├── PHP Application ❌

worker2
 ├── Web App

worker3
 ├── Grafana
```

Although the scheduler has enough CPU and memory, this is not ideal.

The PHP application should never run on the database node.

Kubernetes needs a mechanism to **reserve nodes** for specific workloads.

This is exactly why Taints and Tolerations exist.

---

# What is a Taint?

A **Taint** is applied to a **Node**.

It tells Kubernetes:

> "Do not schedule Pods on this node unless they explicitly tolerate this taint."

Think of it as a **No Entry** sign.

```
Node
 │
 │
 └── "Keep Away"
```

---

# What is a Toleration?

A **Toleration** is applied to a **Pod**.

It tells Kubernetes:

> "This Pod is allowed to run on a node that has a matching taint."

Think of it as an **Access Pass**.

```
Pod
 │
 │
 └── "I have permission."
```

---

# The Relationship

```
Node
 │
 ├── Taint
 │
 ▼
Scheduler
 │
 ▼
Pod
 │
 ├── Matching Toleration ?
 │
 ├── Yes → Schedule
 │
 └── No → Don't Schedule
```

A toleration **does not force** a Pod onto a node.

It only allows scheduling if the Scheduler decides that node is appropriate.

---

# Taint Syntax

```
kubectl taint nodes <node-name> key=value:effect
```

Example:

```bash
kubectl taint nodes worker1 dedicated=db:NoSchedule
```

Breakdown:

| Part | Meaning |
|------|---------|
| dedicated | Key |
| db | Value |
| NoSchedule | Effect |

Verify:

```bash
kubectl describe node worker1
```

Output:

```
Taints:
dedicated=db:NoSchedule
```

---

# Removing a Taint

```
kubectl taint nodes worker1 dedicated=db:NoSchedule-
```

Notice the **-** at the end.

Without it, Kubernetes adds the taint.

With it, Kubernetes removes the taint.

---

# Taint Effects

Kubernetes supports three taint effects.

## 1. NoSchedule

This is the most common.

```
Node
 │
 ├── NoSchedule
 │
 ▼
New Pods Blocked
```

Existing Pods continue running.

New Pods cannot be scheduled unless they tolerate the taint.


---

## 2. PreferNoSchedule

This is a **soft rule**.

The scheduler tries to avoid the node.

If no better node exists, Kubernetes may still place the Pod there.

```
Prefer
Not Required
```

Useful when you want separation but not strict enforcement.

---

## 3. NoExecute

This is the strongest effect.

```
New Pods
Blocked

+

Existing Pods
Evicted
```

If a node receives a `NoExecute` taint:

- New Pods are not scheduled.
- Existing Pods are removed unless they tolerate the taint.

This is commonly used during node failures.

---
# Hands-on Labs

## Lab 1 – Apply a Taint

Check existing taints.

```bash
kubectl describe node worker1 | grep Taints
```

Expected:

```
Taints: <none>
```

Apply a taint.

```bash
kubectl taint nodes worker1 dedicated=db:NoSchedule
```

Verify.

```bash
kubectl describe node worker1
```

---

## Lab 2 – Deploy Without Toleration

Create an Nginx Deployment.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx
```

Deploy.

```bash
kubectl apply -f nginx.yaml
```

Check Pod location.

```bash
kubectl get pods -o wide
```

The Pod should avoid worker1 if other nodes are available.

---

## Lab 3 – Make Every Node Tainted

```bash
kubectl taint nodes worker2 dedicated=apps:NoSchedule

kubectl taint nodes worker3 dedicated=monitoring:NoSchedule
```

Now every node has a taint.

Deploy another Pod.

Expected:

```
Pending
```

Describe the Pod.

```bash
kubectl describe pod <pod-name>
```

Typical Event:

```
0/3 nodes are available

untolerated taint
```

---

## Lab 4 – Add a Toleration

```yaml
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "db"
    effect: "NoSchedule"

  containers:
  - name: nginx
    image: nginx
```

Deploy again.

Verify.

```bash
kubectl get pods -o wide
```

The Pod should now schedule on worker1.

---

# Verify Taints

```bash
kubectl describe node worker1

kubectl describe node worker2

kubectl describe node worker3
```

---

# Verify Pod Placement

```bash
kubectl get pods -o wide
```

Observe the NODE column.

---

# Remove Taints

```bash
kubectl taint nodes worker1 dedicated=db:NoSchedule-

kubectl taint nodes worker2 dedicated=apps:NoSchedule-

kubectl taint nodes worker3 dedicated=monitoring:NoSchedule-
```

Verify.

```
Taints:
<none>
```

---

# Troubleshooting

## Pod Stuck in Pending

Check:

```bash
kubectl describe pod <pod-name>
```

Common Event:

```
0/3 nodes are available

untolerated taint
```

Cause:

The Pod does not have a matching toleration.

Solution:

Add the appropriate toleration or remove the taint.

---

## Verify Taints

```bash
kubectl describe node worker1
```

or

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

---

## Verify Tolerations

```bash
kubectl describe pod <pod-name>
```

Look for:

```
Tolerations:
```

---

# Common Mistakes

## Mistake 1

Thinking a toleration forces a Pod onto a node.

Incorrect.

A toleration only allows scheduling.

---

## Mistake 2

Forgetting the taint effect.

```
NoSchedule

PreferNoSchedule

NoExecute
```

Each behaves differently.

---

## Mistake 3

Applying taints to every node.

If every node is tainted and Pods lack tolerations, all Pods remain Pending.

---

## Mistake 4

Using the wrong key or value.

Keys and values must match exactly.

---

# Best Practices

- Reserve database nodes using `NoSchedule`.
- Use taints for GPU and high-memory nodes.
- Keep monitoring workloads isolated.
- Avoid unnecessary taints.
- Always document taints used in production.
- Verify scheduling using `kubectl get pods -o wide`.

---

# Interview Questions

### What is a Taint?

A property applied to a node that prevents Pods from being scheduled unless they tolerate it.

---

### What is a Toleration?

A property applied to a Pod that allows it to run on a node with a matching taint.

---

### Does a Toleration force scheduling?

No.

It only permits scheduling.

The Scheduler still decides the final node.

---

### Name the three taint effects.

- NoSchedule
- PreferNoSchedule
- NoExecute

---

### Which effect evicts existing Pods?

NoExecute

---

### How do you remove a taint?

```bash
kubectl taint nodes worker1 dedicated=db:NoSchedule-
```

---

# Learning Summary

In this chapter you learned:

- Why Kubernetes introduced Taints & Tolerations
- Taint syntax
- Toleration syntax
- The three taint effects
- Real production use cases
- Hands-on scheduling labs
- Scheduler troubleshooting
- Best practices
- Interview questions

You can now dedicate nodes for specific workloads and control Pod placement using Kubernetes scheduling policies.