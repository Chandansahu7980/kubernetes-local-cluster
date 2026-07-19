# Pod Affinity

## Overview

In the previous chapters, we learned how Kubernetes schedules Pods using:

- NodeSelector
- Node Affinity
- Taints & Tolerations

All of these scheduling methods make decisions based on **Node properties**.

Pod Affinity introduces a different approach.

Instead of asking:

> "Which Node should this Pod run on?"

Kubernetes asks:

> "Is there another Pod that this Pod should be scheduled close to?"

Pod Affinity allows Kubernetes to schedule Pods based on **existing Pod labels**, making it ideal for applications whose components communicate frequently.

---

# Why Was Pod Affinity Introduced?

Consider a simple application.

```
Users
   │
   ▼
PHP Application
   │
   ▼
MySQL Database
```

Without Pod Affinity, Kubernetes may schedule them on different nodes.

```
Worker1
┌──────────────┐
│ PHP          │
└──────────────┘

Worker2
┌──────────────┐
│ MySQL        │
└──────────────┘
```

Every database request travels across the cluster network.

Problems:

- Increased latency
- Additional network traffic
- Higher response time

Now consider Pod Affinity.

```
Worker1

PHP

MySQL
```

Both Pods are placed on the same node.

Benefits:

- Faster communication
- Lower latency
- Better application performance

This is the primary purpose of Pod Affinity.

---

# What is Pod Affinity?

Pod Affinity is a scheduling feature that tells Kubernetes:

> "Schedule this Pod close to another Pod that matches specific labels."

Unlike Node Affinity, Pod Affinity uses **Pod labels** instead of Node labels.

---

# Node Affinity vs Pod Affinity

| Feature | Node Affinity | Pod Affinity |
|----------|---------------|--------------|
| Uses | Node Labels | Pod Labels |
| Scheduler Looks At | Nodes | Existing Pods |
| Purpose | Select Nodes | Stay close to another Pod |

Example:

Node Affinity

```
Run on SSD Nodes
```

Pod Affinity

```
Run close to MySQL Pods
```

---

# Pod Affinity vs Pod Anti-Affinity

Pod Affinity

```
Stay Together
```

Example

- PHP + MySQL
- API + Redis
- Backend + RabbitMQ

---

Pod Anti-Affinity

```
Stay Apart
```

Example

- NGINX replicas
- Web server replicas
- Kafka brokers
- Elasticsearch master nodes

---

# Required vs Preferred Pod Affinity

Exactly like Node Affinity, Pod Affinity has two types.

## Required Pod Affinity

```yaml
requiredDuringSchedulingIgnoredDuringExecution
```

Meaning:

The Pod **must** be scheduled close to another matching Pod.

If no matching Pod exists:

```
Pod

↓

Pending
```

---

## Preferred Pod Affinity

```yaml
preferredDuringSchedulingIgnoredDuringExecution
```

Meaning:

Try to schedule close to another Pod.

If not possible:

```
Schedule Anywhere
```

This is called **Soft Scheduling**.

---

# Understanding labelSelector

Pod Affinity uses Pod labels.

Example Pod

```yaml
labels:
  app: mysql
```

Affinity Rule

```yaml
labelSelector:
  matchExpressions:
  - key: app
    operator: In
    values:
    - mysql
```

The scheduler searches for Pods matching:

```
app=mysql
```

---

# Understanding topologyKey

This is one of the most important concepts.

```yaml
topologyKey:
```

It defines what "close" means.

Same Node

```yaml
topologyKey: kubernetes.io/hostname
```

Same Availability Zone

```yaml
topologyKey: topology.kubernetes.io/zone
```

Same Region

```yaml
topologyKey: topology.kubernetes.io/region
```

Most clusters use:

```yaml
kubernetes.io/hostname
```

meaning:

> Schedule Pods on the same Node.

---

# Scheduler Workflow

```
Deployment
      │
      ▼
Scheduler
      │
Find matching Pods
(labelSelector)
      │
Determine topology
(topologyKey)
      │
Choose best Node
      │
Schedule Pod
```

---

# Lab 1 – Required Pod Affinity

## Deploy MySQL

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: affinity-lab

spec:
  replicas: 1

  selector:
    matchLabels:
      app: mysql

  template:
    metadata:
      labels:
        app: mysql

    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: root123
```

Deploy

```bash
kubectl apply -f mysql.yaml
```

Verify

```bash
kubectl get pods -o wide -n affinity-lab
```

---

## Deploy PHP

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php
  namespace: affinity-lab

spec:
  replicas: 1

  selector:
    matchLabels:
      app: php

  template:
    metadata:
      labels:
        app: php

    spec:

      affinity:
        podAffinity:

          requiredDuringSchedulingIgnoredDuringExecution:

          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - mysql

            topologyKey: kubernetes.io/hostname

      containers:
      - name: nginx
        image: nginx
```

Deploy

```bash
kubectl apply -f php.yaml
```

Verify

```bash
kubectl get pods -o wide -n affinity-lab
```

Expected

```
worker2

mysql

php
```

Both Pods should run on the same node.

---

# Lab 2 – Preferred Pod Affinity

Replace Required with Preferred.

```yaml
affinity:
  podAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - mysql

        topologyKey: kubernetes.io/hostname
```

Deploy.

Delete the MySQL Deployment.

Recreate the PHP Pods.

Expected:

Pods still start successfully.

Why?

Because Preferred Pod Affinity is only a preference.

---

# Lab 3 – Required Node Affinity + Preferred Pod Affinity

```yaml
affinity:

  nodeAffinity:

    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: disktype
          operator: In
          values:
          - ssd

  podAffinity:

    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100

      podAffinityTerm:

        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - mysql

        topologyKey: kubernetes.io/hostname
```

Result

- Pod must run on SSD Nodes.
- Scheduler prefers SSD Nodes already running MySQL.

This is a common production scheduling pattern.

---

# Production Examples

Pod Affinity is commonly used for:

| Application | Reason |
|--------------|--------|
| PHP + MySQL | Reduce latency |
| API + Redis | Faster cache access |
| Backend + RabbitMQ | Faster message processing |
| Application + Cache | Better performance |

---

# Troubleshooting

## Pod Pending

Describe the Pod.

```bash
kubectl describe pod <pod-name>
```

Check the Events section.

---

## Verify Pod Labels

```bash
kubectl get pods --show-labels -n affinity-lab
```

---

## Verify Node Placement

```bash
kubectl get pods -o wide -n affinity-lab
```

---

## Verify Node Labels

```bash
kubectl get nodes --show-labels
```

---

## Common Causes

- Wrong Pod labels
- Incorrect topologyKey
- Required affinity with no matching Pods
- Typographical errors in labelSelector

---

# Best Practices

- Use meaningful labels.
- Prefer Preferred Affinity unless mandatory.
- Keep affinity rules simple.
- Use topologyKey carefully.
- Document your labels.

---

# Common Mistakes

❌ Using Node labels inside Pod Affinity

❌ Forgetting topologyKey

❌ Assuming Preferred guarantees placement

❌ Missing Pod labels

---

# Interview Questions

### What is Pod Affinity?

Pod Affinity is a scheduling feature that places Pods close to other Pods using Pod labels.

---

### What is the difference between Node Affinity and Pod Affinity?

Node Affinity uses Node labels.

Pod Affinity uses Pod labels.

---

### What is topologyKey?

It defines what "close" means, such as the same Node, Zone, or Region.

---

### What happens if Required Pod Affinity cannot be satisfied?

The Pod remains in the Pending state.

---

### What happens if Preferred Pod Affinity cannot be satisfied?

The scheduler places the Pod on another suitable Node.

---

Pod Affinity enables Kubernetes to place related workloads close together, reducing network latency and improving application performance. In production, it is often combined with Node Affinity and Pod Anti-Affinity to build fast, resilient, and highly available applications.