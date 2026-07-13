# Kubernetes Resource Requests, Limits & QoS

# Overview

Every application running inside Kubernetes consumes system resources such as:

- CPU
- Memory
- Storage
- Network

If Kubernetes allows every application to consume unlimited resources, one application can affect the stability of the entire cluster.

To solve this problem, Kubernetes introduced **Resource Requests** and **Resource Limits**.

These help Kubernetes:

- Schedule Pods on suitable Nodes.
- Prevent resource starvation.
- Improve cluster stability.
- Protect applications from consuming excessive CPU or memory.

---

# Why Resource Management is Important

Imagine a Kubernetes cluster with three worker nodes.

```
Worker-1
CPU : 2 Core
Memory : 2 GB

Worker-2
CPU : 2 Core
Memory : 2 GB

Worker-3
CPU : 2 Core
Memory : 2 GB
```

Now deploy several applications.

```
MySQL

PHP

Grafana

Prometheus

Jenkins
```

Without any resource limits, one application may consume all available CPU or Memory.

Consequences:

- Slow applications
- Unresponsive Nodes
- Random process termination
- Out Of Memory (OOM) errors

Resource Management prevents these situations.

---

# Resource Requests

A **Request** defines the minimum resources that a Pod requires.

Example:

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "128Mi"
```

This tells Kubernetes:

> "Schedule this Pod only if a Node can guarantee at least 250m CPU and 128Mi Memory."

The Kubernetes Scheduler uses **only Requests** while selecting a Node.

---

# Resource Limits

A **Limit** defines the maximum resources that a container can consume.

Example:

```yaml
resources:
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Meaning:

- Maximum CPU = 500m
- Maximum Memory = 256Mi

If the application exceeds:

- CPU → Kubernetes throttles CPU usage.
- Memory → Kubernetes terminates the container (OOMKilled).

---

# Requests vs Limits

| Request | Limit |
|----------|--------|
| Minimum guaranteed resources | Maximum allowed resources |
| Used by Scheduler | Enforced by Kubelet/Linux Kernel |
| Decides Pod placement | Prevents excessive resource usage |
| Does not kill Pod | Memory limit may kill Pod |

---

# Scheduler Workflow

```
Deployment Created
        │
        ▼
Scheduler Reads Requests
        │
        ▼
Find Suitable Node
        │
        ▼
Enough Resources?
       │
   ┌───┴────┐
   │        │
  Yes       No
   │        │
   ▼        ▼
Running   Pending
```

Notice:

The Scheduler checks **Requests**, not Limits.

---

# CPU Units

Kubernetes measures CPU in **millicores (m).**

| CPU | Meaning |
|------|----------|
| 1000m | 1 CPU Core |
| 500m | Half Core |
| 250m | Quarter Core |
| 100m | One Tenth Core |

Examples:

```
1000m = 1 CPU

500m = 0.5 CPU

250m = 0.25 CPU
```

---

# Memory Units

Memory uses binary units.

| Value | Meaning |
|--------|----------|
| 128Mi | 128 MiB |
| 256Mi | 256 MiB |
| 512Mi | 512 MiB |
| 1Gi | 1024 MiB |

Common mistake:

```
Mi != MB

Gi != GB
```

Always use Kubernetes-supported units.

---

# Capacity vs Allocatable

View Node information.

```bash
kubectl describe node worker1
```

Example:

```
Capacity

CPU : 2

Memory : 2010780Ki
```

```
Allocatable

CPU : 2

Memory : 1908380Ki
```

Why are they different?

Because Kubernetes reserves resources for:

- Operating System
- kubelet
- containerd
- kube-proxy
- Kernel

Pods can consume only the **Allocatable** resources.

---

# Allocated Resources

View:

```bash
kubectl describe node worker1
```

Example:

```
Allocated Resources

CPU Requests : 250m

CPU Limits : 0

Memory Requests : 0

Memory Limits : 0
```

This section shows how much CPU and Memory have already been reserved by running Pods.

---

# Lab 1 – Requests and Limits

Create:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-demo
  template:
    metadata:
      labels:
        app: resource-demo
    spec:
      containers:
      - name: nginx
        image: nginx

        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"

          limits:
            cpu: "200m"
            memory: "256Mi"
```

Deploy:

```bash
kubectl apply -f resource-demo.yaml
```

Verify:

```bash
kubectl describe node worker1
```

Observe the Allocated Resources section.

---

# Lab 2 – Pending Pod

Create a Deployment requesting more resources than available.

Example:

```
CPU : 4

Memory : 4Gi
```

Deploy.

```
kubectl apply -f huge-app.yaml
```

Check:

```
kubectl get pods
```

Result:

```
Pending
```

Describe the Pod.

```
kubectl describe pod <pod-name>
```

Expected Events:

```
0/3 nodes are available

Insufficient cpu

Insufficient memory
```

This demonstrates how the Scheduler prevents Pods from running on Nodes without sufficient resources.

---

# Lab 3 – OOMKilled

Create a Pod that intentionally consumes more Memory than its configured Limit.

Example:

```
Request

64Mi

Limit

128Mi

Application Uses

300Mi
```

Result:

```
OOMKilled
```

Verify:

```bash
kubectl describe pod <pod-name>
```

Look for:

```
Last State

Terminated

Reason

OOMKilled
```

---

# CPU vs Memory

## CPU

When CPU usage exceeds the configured Limit:

```
Application

↓

CPU Throttled

↓

Application Slower

↓

Container Continues Running
```

The container is not terminated.

---

## Memory

When Memory usage exceeds the configured Limit:

```
Application

↓

Memory Exceeded

↓

OOMKilled

↓

Container Restarted
```

The container is terminated immediately.

---

# Why Memory and CPU Behave Differently

CPU is a time-shared resource.

Linux simply gives the application less CPU time.

Memory is a finite resource.

Once RAM is exhausted, Linux must free memory by terminating a process.

---
# Useful Commands

View Nodes

```bash
kubectl get nodes
```

Describe Node

```bash
kubectl describe node worker1
```

View Pods

```bash
kubectl get pods
```

Describe Pod

```bash
kubectl describe pod <pod-name>
```

View Previous Logs

```bash
kubectl logs <pod-name> --previous
```

Watch Pods

```bash
kubectl get pods -w
```

---

# Common Errors

## Pod Pending

Cause:

```
Insufficient cpu

Insufficient memory
```

Solution:

- Reduce Requests.
- Add Worker Nodes.
- Increase Node capacity.

---

## OOMKilled

Cause:

Memory Limit exceeded.

Solution:

- Increase Memory Limit.
- Reduce application Memory usage.

---

## CPU Throttling

Cause:

CPU usage exceeds Limit.

Solution:

Increase CPU Limit.

---

# Troubleshooting Checklist

Check Node capacity.

```bash
kubectl describe node
```

Check Pod Events.

```bash
kubectl describe pod
```

Check Restart Count.

```bash
kubectl get pods
```

Check Previous Logs.

```bash
kubectl logs <pod-name> --previous
```

Check Allocated Resources.

```bash
kubectl describe node
```

---

# Best Practices

- Always define Requests.
- Always define Limits.
- Avoid BestEffort Pods in production.
- Continuously monitor CPU and Memory usage.
- Review Requests and Limits periodically as application usage changes.

---

# Interview Questions

## What is the difference between Requests and Limits?

Requests define the minimum guaranteed resources used by the Scheduler for Pod placement.

Limits define the maximum resources a container is allowed to consume.

---

## Does the Scheduler use Requests or Limits?

Only Requests.

---

## What happens if Memory exceeds its Limit?

The container is terminated with **OOMKilled**.

---

## What happens if CPU exceeds its Limit?

The container continues running, but CPU usage is throttled.
