# Pod Anti-Affinity

## Overview

In the previous chapter, we learned about **Pod Affinity**, where Kubernetes schedules Pods **close to other Pods** based on Pod labels.

Pod Anti-Affinity is the opposite.

Instead of saying:

> "Place this Pod close to another Pod."

we say:

> "Do NOT place this Pod close to another Pod."

This feature is primarily used to improve **High Availability (HA)** by spreading application replicas across multiple nodes.

---

# Why Was Pod Anti-Affinity Introduced?

Imagine an NGINX Deployment with three replicas.

```yaml
replicas: 3
```

Kubernetes may schedule them like this:

```
Worker1

nginx-1
nginx-2
nginx-3


Worker2

(empty)


Worker3

(empty)
```

Everything looks healthy.

```
3/3 Running
```

But what happens if Worker1 crashes?

```
Worker1 ❌
```

Result

```
nginx-1 ❌

nginx-2 ❌

nginx-3 ❌
```

All replicas are lost at once.

---

# Desired Behavior

Instead, Kubernetes should spread replicas.

```
Worker1

nginx-1


Worker2

nginx-2


Worker3

nginx-3
```

Now if Worker2 fails:

```
Worker1

nginx-1


Worker2 ❌


Worker3

nginx-3
```

Only one replica is lost.

The application remains available.

This is why Pod Anti-Affinity exists.

---

# What is Pod Anti-Affinity?

Pod Anti-Affinity is a scheduling feature that tells Kubernetes:

> "Avoid placing this Pod near other Pods that match these labels."

It helps distribute replicas across the cluster, improving fault tolerance and resilience.

---

# Pod Affinity vs Pod Anti-Affinity

| Pod Affinity | Pod Anti-Affinity |
|---------------|-------------------|
| Keep Pods together | Keep Pods apart |
| Improve communication | Improve availability |
| Reduce latency | Reduce failure impact |
| Example: PHP + MySQL | Example: NGINX Replicas |

---

# Required vs Preferred Pod Anti-Affinity

Like Node Affinity and Pod Affinity, Pod Anti-Affinity has two modes.

---

## Required Pod Anti-Affinity

```yaml
requiredDuringSchedulingIgnoredDuringExecution
```

Meaning:

The scheduler **must not** place matching Pods on the same topology.

If no suitable node exists:

```
Pod

↓

Pending
```

---

## Preferred Pod Anti-Affinity

```yaml
preferredDuringSchedulingIgnoredDuringExecution
```

Meaning:

Try to spread Pods.

If not possible:

```
Schedule Anyway
```

This provides better scheduling flexibility.

---

# Understanding topologyKey

`topologyKey` defines the boundary for anti-affinity.

Most common:

```yaml
topologyKey: kubernetes.io/hostname
```

Meaning:

```
One Pod per Node
```

Other examples:

Same Zone

```yaml
topologyKey: topology.kubernetes.io/zone
```

Same Region

```yaml
topologyKey: topology.kubernetes.io/region
```

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
Check topology
(hostname)
      │
Avoid placing Pod
on same topology
      │
Choose another Node
```

---

# Lab 1 – Default Scheduling

Deploy a normal NGINX Deployment.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-normal
  namespace: affinity-lab

spec:
  replicas: 3

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
      - name: nginx
        image: nginx
```

Deploy

```bash
kubectl apply -f nginx-normal.yaml
```

Verify

```bash
kubectl get pods -o wide -n affinity-lab
```

Observe where Kubernetes places the Pods.

---

# Lab 2 – Required Pod Anti-Affinity

Create:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-required
  namespace: affinity-lab

spec:
  replicas: 3

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:

      affinity:
        podAntiAffinity:

          requiredDuringSchedulingIgnoredDuringExecution:

          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - nginx

            topologyKey: kubernetes.io/hostname

      containers:
      - name: nginx
        image: nginx
```

Deploy

```bash
kubectl apply -f nginx-required.yaml
```

Verify

```bash
kubectl get pods -o wide -n affinity-lab
```

Expected

```
Worker1

nginx-1


Worker2

nginx-2


Worker3

nginx-3
```

Each replica is scheduled on a different node.

---

# Lab 3 – Scale Beyond Cluster Size

Scale to four replicas.

```bash
kubectl scale deployment nginx-required \
--replicas=4 \
-n affinity-lab
```

Verify

```bash
kubectl get pods -n affinity-lab
```

Expected

```
3 Running

1 Pending
```

Describe the Pending Pod.

```bash
kubectl describe pod <pending-pod> -n affinity-lab
```

You should see scheduling events indicating that no node satisfied the anti-affinity rule.

---

# Lab 4 – Preferred Pod Anti-Affinity

```yaml
affinity:

  podAntiAffinity:

    preferredDuringSchedulingIgnoredDuringExecution:

    - weight: 100

      podAffinityTerm:

        labelSelector:

          matchExpressions:

          - key: app
            operator: In
            values:
            - nginx

        topologyKey: kubernetes.io/hostname
```

Deploy with four replicas.

Expected

```
Worker1

nginx-1

nginx-4


Worker2

nginx-2


Worker3

nginx-3
```

Kubernetes spreads Pods first.

When all nodes already contain one replica, it schedules the remaining Pod on an existing node.

---

# Lab 5 – Combine Scheduling Features

Deploy an application that uses:

- Required Node Affinity
- Preferred Pod Anti-Affinity

Result

```
Only SSD Nodes

+

Spread replicas across SSD Nodes
```

This resembles many production deployments.

---

# Production Examples

Pod Anti-Affinity is commonly used for:

| Application | Reason |
|--------------|--------|
| NGINX Replicas | High Availability |
| API Replicas | Fault Tolerance |
| Kafka Brokers | Prevent single-node failures |
| Elasticsearch Master Nodes | Cluster stability |
| Redis Sentinel | Better resilience |

---

# Troubleshooting

## Pod Pending

Describe the Pod.

```bash
kubectl describe pod <pod-name>
```

Look for scheduler events such as:

```
didn't match pod anti-affinity rules
```

---

## Verify Labels

```bash
kubectl get pods --show-labels -n affinity-lab
```

---

## Verify Pod Placement

```bash
kubectl get pods -o wide -n affinity-lab
```

---

## Verify Node Count

```bash
kubectl get nodes
```

Remember:

If you have three nodes and use Required Pod Anti-Affinity, only three replicas can be scheduled.

---

# Best Practices

- Use Pod Anti-Affinity for replicated workloads.
- Prefer Preferred Anti-Affinity unless strict separation is required.
- Use meaningful Pod labels.
- Combine with Resource Requests and Limits.
- Monitor Pending Pods after scaling.

---

# Common Mistakes

❌ Forgetting topologyKey

❌ Incorrect labelSelector

❌ Using Required Anti-Affinity on a small cluster

❌ Expecting Kubernetes to move existing Pods automatically

---

# Interview Questions

### What is Pod Anti-Affinity?

Pod Anti-Affinity is a scheduling feature that prevents Pods with matching labels from being placed close to each other.

---

### Why is Pod Anti-Affinity used?

To improve High Availability and Fault Tolerance by spreading replicas across different nodes.

---

### Difference between Pod Affinity and Pod Anti-Affinity?

Pod Affinity keeps related Pods together.

Pod Anti-Affinity keeps replicas apart.

---

### What happens if Required Pod Anti-Affinity cannot be satisfied?

The Pod remains in the Pending state until a suitable node becomes available.

---

### What happens if Preferred Pod Anti-Affinity cannot be be satisfied?

The scheduler still places the Pod on the best available node.

---

# Best Production Practices

For critical production workloads:

- Use at least three worker nodes.
- Combine Resource Requests with Pod Anti-Affinity.
- Use Readiness and Liveness Probes.
- Prefer Preferred Pod Anti-Affinity for better scheduling flexibility.
- Monitor Pending Pods using Prometheus and Grafana.
- Consider **Topology Spread Constraints** for more even and scalable Pod distribution in modern Kubernetes clusters.