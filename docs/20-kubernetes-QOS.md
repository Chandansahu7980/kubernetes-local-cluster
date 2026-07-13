# Kubernetes QoS (Quality of Service)

# Overview

Quality of Service (QoS) is a Kubernetes feature that classifies every
Pod based on its CPU and Memory Requests and Limits.

QoS helps Kubernetes decide **which Pods should be protected and which
Pods should be evicted first** when a Node runs out of memory.

------------------------------------------------------------------------

# Why Kubernetes Introduced QoS

Imagine a node with 2 GB RAM running three applications:

-   MySQL
-   PHP Application
-   Test Nginx

If total memory usage exceeds the node capacity, Kubernetes must free
memory.

Instead of killing Pods randomly, Kubernetes follows QoS classes.

Eviction order:

    BestEffort
        ↓
    Burstable
        ↓
    Guaranteed

Guaranteed Pods are protected the most.

------------------------------------------------------------------------

# The Three QoS Classes

## 1. Guaranteed

Requirements:

-   Requests must be defined.
-   Limits must be defined.
-   Requests must equal Limits for CPU and Memory.

Example:

``` yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"
```

Characteristics:

-   Highest priority
-   Least likely to be evicted
-   Best for databases, message brokers and critical applications

------------------------------------------------------------------------

## 2. Burstable

Requirements:

-   Requests and Limits exist.
-   Request is less than Limit for at least one resource.

Example:

``` yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Characteristics:

-   Guaranteed minimum resources
-   Can use extra resources when available
-   Most common QoS for web applications

------------------------------------------------------------------------

## 3. BestEffort

Requirements:

-   No Requests
-   No Limits

Example:

``` yaml
containers:
- name: nginx
  image: nginx
```

Characteristics:

-   Lowest priority
-   First Pods evicted during Memory Pressure
-   Not recommended for production

------------------------------------------------------------------------

# QoS Comparison

  QoS          Requests   Limits   Request = Limit   Eviction Priority
  ------------ ---------- -------- ----------------- -------------------
  Guaranteed   Yes        Yes      Yes               Last
  Burstable    Yes        Yes      No                Middle
  BestEffort   No         No       No                First

------------------------------------------------------------------------

# How Kubernetes Determines QoS

    Requests & Limits Defined?

            │
            ├── No
            │      │
            │      ▼
            │  BestEffort
            │
            ▼

    Requests == Limits ?

            │
        ┌───┴────┐
        │        │
       Yes       No
        │        │
        ▼        ▼
    Guaranteed Burstable

------------------------------------------------------------------------

# Hands-on Lab

Create one Pod of each type.

Verify:

``` bash
kubectl describe pod <pod-name>
```

Look for:

    QoS Class:

Or:

``` bash
kubectl get pod <pod-name> -o yaml
```

Example:

``` yaml
qosClass: Guaranteed
```

------------------------------------------------------------------------

# Memory Pressure Example

Node Memory:

    2 GB

Running Pods:

  Pod     QoS          Memory
  ------- ------------ --------
  MySQL   Guaranteed   800Mi
  PHP     Burstable    700Mi
  Test    BestEffort   700Mi

Total usage exceeds available memory.

Kubernetes evicts:

1.  BestEffort
2.  Burstable
3.  Guaranteed (last)

------------------------------------------------------------------------

# Useful Commands

``` bash
kubectl describe pod <pod>

kubectl get pod <pod> -o yaml

kubectl get pods
```

------------------------------------------------------------------------

# Best Practices

-   Use Guaranteed QoS for databases.
-   Use Burstable QoS for most applications.
-   Avoid BestEffort in production.
-   Always configure Requests and Limits.

------------------------------------------------------------------------

# Interview Questions

**Q1. What is QoS?**

A mechanism that classifies Pods based on Requests and Limits and
determines eviction priority.

**Q2. What are the three QoS classes?**

-   Guaranteed
-   Burstable
-   BestEffort

**Q3. Which Pods are evicted first?**

BestEffort Pods.

**Q4. Which Pods are evicted last?**

Guaranteed Pods.

**Q5. Can a Pod with only Requests be Guaranteed?**

No. It becomes Burstable because Limits are missing.

------------------------------------------------------------------------

# Summary

-   QoS protects critical workloads.
-   Kubernetes automatically assigns a QoS class.
-   QoS mainly affects Pod eviction during memory pressure.
-   Guaranteed \> Burstable \> BestEffort in terms of protection.