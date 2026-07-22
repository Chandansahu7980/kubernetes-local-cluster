# Topology Spread Constraints

## Overview

In the previous chapter, we learned about **Pod Anti-Affinity**, which prevents Pods with the same labels from being scheduled together.

Although Pod Anti-Affinity helps improve **High Availability (HA)**, it has one limitation:

> It focuses on **keeping Pods apart**, not on **keeping Pods evenly distributed**.

To solve this problem, Kubernetes introduced **Topology Spread Constraints**.

Topology Spread Constraints allow the scheduler to **balance Pods evenly across Nodes, Availability Zones, Regions, or any other topology domain**.

Today, this is the **recommended approach** for distributing application replicas in production Kubernetes clusters.

---

# Why Were Topology Spread Constraints Introduced?

Imagine a cluster with three worker nodes.

```
Worker1

Worker2

Worker3
```

Deploy an application with six replicas.

```
replicas: 6
```

Without any scheduling rules, Kubernetes may distribute Pods unevenly.

```
Worker1

Pod1
Pod2
Pod3


Worker2

Pod4


Worker3

Pod5
Pod6
```

Although all Pods are running, the workload is not balanced.

This creates problems:

- Uneven CPU usage
- Uneven Memory usage
- Higher failure impact
- Poor resource utilization

Ideally, we want:

```
Worker1

Pod1
Pod2


Worker2

Pod3
Pod4


Worker3

Pod5
Pod6
```

Exactly balanced.

This is the purpose of **Topology Spread Constraints**.

---

# What is a Topology?

A topology is simply a logical grouping of Nodes.

Examples:

```
Node
```

```
Availability Zone
```

```
Region
```

```
Rack
```

Kubernetes identifies these groups using **Node Labels**.

Example:

```
kubernetes.io/hostname
```

or

```
topology.kubernetes.io/zone
```

---

# What is a Topology Domain?

A topology domain is a unique value of the selected topology key.

Example:

```
topologyKey:
kubernetes.io/hostname
```

Nodes

```
master

worker1

worker2
```

There are three topology domains.

Another example

```
topologyKey:

topology.kubernetes.io/zone
```

Nodes

```
Zone A

Zone A

Zone B
```

There are only two topology domains.

---

# Pod Anti-Affinity vs Topology Spread Constraints

| Pod Anti-Affinity | Topology Spread Constraints |
|-------------------|-----------------------------|
| Keeps Pods apart | Balances Pods evenly |
| Uses Pod labels | Uses Pod labels |
| Focuses on separation | Focuses on distribution |
| Better for HA | Better for HA + Resource Balancing |
| Older scheduling method | Modern scheduling method |

---

# Topology Spread Constraint Syntax

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: nginx
```

Let's understand every field.

---

# maxSkew

This is the most important field.

It defines the **maximum allowed difference** between the number of matching Pods in any two topology domains.

Example

```
Worker1 = 2 Pods

Worker2 = 2 Pods

Worker3 = 2 Pods
```

Difference

```
0
```

Perfectly balanced.

Another example

```
Worker1 = 3

Worker2 = 2

Worker3 = 2
```

Difference

```
1
```

If

```yaml
maxSkew: 1
```

This is allowed.

Not allowed

```
Worker1 = 5

Worker2 = 2

Worker3 = 2
```

Difference

```
3
```

Greater than maxSkew.

---

# topologyKey

Defines the topology across which Pods should be balanced.

Most common

```yaml
topologyKey: kubernetes.io/hostname
```

Meaning

Spread Pods evenly across Nodes.

Other examples

```
topology.kubernetes.io/zone
```

Spread across Availability Zones.

```
topology.kubernetes.io/region
```

Spread across Regions.

---

# whenUnsatisfiable

This tells Kubernetes what to do when it cannot satisfy the spread constraint.

---

## DoNotSchedule

Hard rule.

```
Cannot maintain balance

↓

Pod remains Pending
```

---

## ScheduleAnyway

Soft rule.

```
Try to maintain balance.

If impossible,

schedule the Pod anyway.
```

This is similar to:

- Preferred Node Affinity
- Preferred Pod Affinity
- Preferred Pod Anti-Affinity

---

# labelSelector

Determines which Pods should be counted.

Example

```yaml
labelSelector:

  matchLabels:

    app: nginx
```

The scheduler only counts Pods with

```
app=nginx
```

Other Pods are ignored.

---

# Scheduler Workflow

```
Deployment
  ↓
Scheduler
  ↓
Find matching Pods
  ↓
Group by topology
  ↓
Count Pods
  ↓
Calculate Skew
  ↓
Choose Best Node
```

Unlike Pod Anti-Affinity, the scheduler counts Pods instead of only checking whether another Pod exists.

---

# Lab 1 – Deploy Without Topology Spread

Create

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-normal
  namespace: affinity-lab

spec:
  replicas: 6

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

Observe how Pods are distributed.

---

# Lab 2 – Deploy With Topology Spread Constraints

Create

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-spread
  namespace: affinity-lab

spec:
  replicas: 6

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:

      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: nginx

      containers:
      - name: nginx
        image: nginx
```

Deploy

```bash
kubectl apply -f nginx-spread.yaml
```

Verify

```bash
kubectl get pods -o wide -n affinity-lab
```

On a cluster with three schedulable worker nodes, the expected result is:

```
Worker1
2 Pods

--------------

Worker2
2 Pods

--------------

Worker3
2 Pods
```

---

# Lab 3 – Understanding Pending Pods (Important)

During our lab, the deployment did **not** behave as expected.

Pods remained in the **Pending** state.

Events showed:

```
0/3 nodes are available

1 node had untolerated taint

2 nodes didn't match topology spread constraints
```

Why?

Our Vagrant cluster contained:

```
Master (Control Plane)

Worker1

Worker2
```

The control-plane node had the default taint:

```
node-role.kubernetes.io/control-plane:NoSchedule
```

Although the master node was part of the topology (because it has the `kubernetes.io/hostname` label), Pods could not be scheduled there.

As a result, Kubernetes could not maintain the requested balance across all topology domains, so additional Pods remained **Pending** when using:

```yaml
whenUnsatisfiable: DoNotSchedule
```

This is a common learning issue in small lab clusters.

---

# Lab 4 – ScheduleAnyway

Modify:

```yaml
whenUnsatisfiable: ScheduleAnyway
```

Apply the Deployment again.

Observe that Kubernetes schedules all Pods, even if the distribution is not perfectly balanced.

This demonstrates the difference between a **hard** and a **soft** scheduling rule.

---

# Best Practices

- Use `topology.kubernetes.io/zone` in cloud environments.
- Use `kubernetes.io/hostname` for balancing across nodes.
- Prefer `ScheduleAnyway` unless strict balancing is required.
- Combine with Resource Requests and Limits.
- Combine with Readiness and Liveness Probes.
- Monitor scheduling decisions using `kubectl describe pod`.

---

# Troubleshooting

## Check Node Labels

```bash
kubectl get nodes --show-labels
```

---

## Check Pod Placement

```bash
kubectl get pods -o wide
```

---

## Describe Pending Pod

```bash
kubectl describe pod <pod-name>
```

Look for scheduler events.

---

## Verify Taints

```bash
kubectl describe node master
```

or

```bash
kubectl get node master -o jsonpath='{.spec.taints}'
```

A control-plane taint may prevent Pods from being scheduled, affecting topology balancing in small lab environments.

---

# Common Mistakes

❌ Assuming all nodes are schedulable

❌ Forgetting `labelSelector`

❌ Using an incorrect `topologyKey`

❌ Setting `maxSkew` too strictly

❌ Confusing Pod Anti-Affinity with Topology Spread Constraints

---

# Interview Questions

### What is a Topology Spread Constraint?

A scheduling feature that distributes matching Pods evenly across topology domains such as Nodes or Availability Zones.

---

### What is `maxSkew`?

The maximum allowed difference in the number of matching Pods between topology domains.

---

### Difference between Pod Anti-Affinity and Topology Spread Constraints?

Pod Anti-Affinity separates Pods, while Topology Spread Constraints aim to keep Pods evenly distributed.

---

### What happens when `whenUnsatisfiable` is `DoNotSchedule`?

If the scheduler cannot satisfy the spread constraint, the Pod remains in the **Pending** state.

---

### What happens when `whenUnsatisfiable` is `ScheduleAnyway`?

The scheduler prefers balanced placement but schedules the Pod even if perfect balance cannot be achieved.

---

Topology Spread Constraints are the modern Kubernetes mechanism for distributing Pods evenly across Nodes, Zones, or Regions. They provide better scalability and more predictable scheduling than Pod Anti-Affinity, making them a preferred choice for production Kubernetes deployments.