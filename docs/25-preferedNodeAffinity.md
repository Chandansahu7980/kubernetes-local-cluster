# Preferred Node Affinity

## Overview

In the previous chapter, you learned about **Required Node Affinity**, where a Pod **must** satisfy scheduling rules before it can be scheduled.

In this chapter, you'll learn **Preferred Node Affinity**, which allows Kubernetes to **prefer** certain Nodes while still scheduling the Pod if those preferred Nodes are unavailable.

Unlike Required Node Affinity, Preferred Node Affinity provides **soft scheduling**, allowing the Scheduler to make intelligent decisions without leaving Pods in the **Pending** state.

This is the scheduling method most commonly used in production Kubernetes clusters.

---

# What is Preferred Node Affinity?

Preferred Node Affinity tells Kubernetes:

> **"If possible, schedule this Pod on Nodes matching these labels. If not, choose another suitable Node."**

Unlike Required Node Affinity, Kubernetes **does not fail scheduling** if no preferred Node exists.

Instead, it ranks available Nodes and selects the most suitable one.

---

# Preferred Node Affinity Syntax

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
```

Breaking down the name:

| Part | Meaning |
|------|---------|
| preferred | Soft rule |
| DuringScheduling | Evaluated only during scheduling |
| IgnoredDuringExecution | Changes after scheduling are ignored |

---

# Scheduler Scoring

Instead of filtering Nodes, Kubernetes assigns **scores**.

Example Cluster

| Node | Labels |
|------|---------|
| worker1 | SSD, East |
| worker2 | SSD, West |
| worker3 | HDD, East |

Preference

```
Prefer SSD
```

Scheduler Score

| Node | Score |
|------|------|
| worker1 | 100 |
| worker2 | 100 |
| worker3 | 0 |

The Scheduler chooses the highest-scoring Node.

---

# Understanding Weight

Each preferred rule has a **weight**.

```yaml
weight: 100
```

Range:

```
1

↓

100
```

Higher value means higher priority.

Example:

```
Prefer SSD

Weight 100

Prefer East

Weight 20
```

SSD is considered much more important than the region.

---

# Lab Setup

Verify labels.

```bash
kubectl get nodes --show-labels
```

Example

| Node | Labels |
|------|-------------------------------|
| worker1 | disktype=ssd, region=east |
| worker2 | disktype=ssd, region=west |
| worker3 | disktype=hdd, region=east |

---

# Lab 1 – Prefer SSD Nodes

Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-preferred
spec:
  replicas: 4
  selector:
    matchLabels:
      app: nginx-preferred
  template:
    metadata:
      labels:
        app: nginx-preferred
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: disktype
                operator: In
                values:
                - ssd

      containers:
      - name: nginx
        image: nginx
```

Deploy

```bash
kubectl apply -f nginx-preferred.yaml
```

Verify

```bash
kubectl get pods -o wide
```

Expected

Most Pods should be scheduled on:

- worker1
- worker2

Worker3 is still eligible because this is only a preference.

---

# Lab 2 – Non-Existing Preferred Label

Modify:

```yaml
values:
- nvme
```

Deploy.

Verify.

```bash
kubectl get pods
```

Expected

Pods are still scheduled successfully.

Why?

Because Kubernetes couldn't satisfy the preference but found suitable Nodes.

Unlike Required Node Affinity, Pods **do not remain Pending**.

---

# Lab 3 – Multiple Preferred Rules

Deployment

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:

    - weight: 80
      preference:
        matchExpressions:
        - key: disktype
          operator: In
          values:
          - ssd

    - weight: 20
      preference:
        matchExpressions:
        - key: region
          operator: In
          values:
          - east
```

Scheduler Scoring

| Node | SSD | East | Total |
|------|----:|-----:|------:|
| worker1 | 80 | 20 | **100** |
| worker2 | 80 | 0 | **80** |
| worker3 | 0 | 20 | **20** |

Expected

Pods are most likely scheduled on **worker1**.

---

# Lab 4 – Required + Preferred Together

This is the most common production configuration.

Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-production
  template:
    metadata:
      labels:
        app: nginx-production
    spec:
      affinity:
        nodeAffinity:

          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disktype
                operator: In
                values:
                - ssd

          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: region
                operator: In
                values:
                - east

      containers:
      - name: nginx
        image: nginx
```

Explanation

The Scheduler first applies the required rule.

```
Must be SSD
```

Remaining Nodes

```
worker1

worker2
```

Next it applies the preferred rule.

```
Prefer East
```

Scheduler Scores

| Node | Required | Preferred | Result |
|------|----------|-----------|--------|
| worker1 | ✔ | ✔ | Selected |
| worker2 | ✔ | ✘ | Backup |
| worker3 | ✘ | ✔ | Rejected |

Expected

Pods should run on **worker1**.

If worker1 becomes unavailable, Kubernetes schedules Pods on **worker2** because it still satisfies the required rule.

---

# Real Production Example

Cluster

| Node | Labels |
|------|---------|
| worker1 | database=true, zone=east |
| worker2 | database=true, zone=west |
| worker3 | web=true |

MySQL Deployment

```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
  - matchExpressions:
    - key: database
      operator: In
      values:
      - "true"

preferredDuringSchedulingIgnoredDuringExecution:
- weight: 100
  preference:
    matchExpressions:
    - key: zone
      operator: In
      values:
      - east
```

Result

- Database Pods always run on database Nodes.
- East zone is preferred.
- West zone is used if East is unavailable.

This provides high availability without violating mandatory requirements.

---

# Scheduler Decision Process

```
Deployment
      │
      ▼
Required Affinity
      │
      ▼
Remove Non-Matching Nodes
      │
      ▼
Preferred Affinity
      │
      ▼
Assign Scores
      │
      ▼
Highest Score Wins
```

---

# Troubleshooting

## Pods Scheduled on Non-Preferred Nodes

Reason

Preferred rules are not mandatory.

Kubernetes may choose another suitable Node.

---

## Pod Pending

Preferred Node Affinity alone never causes Pending Pods.

If a Pod is Pending, check:

- Required Node Affinity
- Taints
- Resource Requests
- PVC Binding
- Node Conditions

---

## Verify Labels

```bash
kubectl get nodes --show-labels
```

---

## Verify Pod Placement

```bash
kubectl get pods -o wide
```

---

## Inspect Pod

```bash
kubectl describe pod <pod-name>
```

Review the Events section for scheduling decisions.

---

# Best Practices

- Use Required Affinity only for mandatory requirements.
- Use Preferred Affinity for optimization.
- Keep weights meaningful.
- Avoid too many preference rules.
- Combine Required and Preferred for production workloads.
- Document Node Labels used in your cluster.

---

# Common Mistakes

### Mistake 1

Using Preferred Affinity when scheduling must be enforced.

Use Required Affinity instead.

---

### Mistake 2

Assuming weight guarantees scheduling.

Weights influence ranking but do not override mandatory scheduling rules.

---

### Mistake 3

Assigning every preference a weight of 100.

Use different weights to express priority.

---

# Interview Questions

### What is Preferred Node Affinity?

A soft scheduling mechanism that tells Kubernetes to prefer certain Nodes but still allows scheduling elsewhere if needed.

---

### What is the difference between Required and Preferred Node Affinity?

Required Affinity is mandatory and may leave Pods Pending.

Preferred Affinity is optional and influences Node selection through scoring.

---

### What is Weight?

A value from **1 to 100** that indicates the importance of a preferred rule during Node scoring.

---

### Can Required and Preferred Affinity be used together?

Yes.

This is the recommended production approach.

---

### Does Preferred Affinity prevent scheduling?

No.

It only influences which Node is preferred.