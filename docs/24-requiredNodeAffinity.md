# Required Node Affinity

## Overview

Kubernetes automatically schedules Pods onto available Nodes based on resource availability, node health, scheduling policies, and other constraints.

Sometimes, however, an application **must** run only on a specific type of node.

For example:

- MySQL should run only on SSD nodes.
- AI workloads should run only on GPU nodes.
- Monitoring components should run only on monitoring nodes.
- Production applications should never run on development nodes.

To enforce these requirements, Kubernetes provides **Node Affinity**.

Node Affinity allows a Pod to define scheduling rules based on **Node Labels**.

This chapter focuses on **Required Node Affinity**, where Kubernetes **must** satisfy the scheduling rule before placing a Pod.

---

# What is Required Node Affinity?

Required Node Affinity tells Kubernetes:

> **This Pod MUST run only on Nodes that satisfy these rules.**

If Kubernetes cannot find a matching Node,

the Pod remains:

```
Pending
```

This is known as **Hard Scheduling**.
---

# Required Node Affinity Syntax

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
```

This long name can be understood as:

| Part | Meaning |
|------|---------|
| required | Rule must be satisfied |
| DuringScheduling | Checked only while scheduling |
| IgnoredDuringExecution | Label changes after scheduling are ignored |

---

# Why "IgnoredDuringExecution"?

Suppose a Pod is already running.

```
worker1
disktype=ssd
```

Later someone removes the label.

```
kubectl label node worker1 disktype-
```

Will Kubernetes evict the Pod?

**No.**

The affinity rule is checked **only when the Pod is scheduled**.

Once running, Kubernetes ignores future label changes.

Hence the name:

```
IgnoredDuringExecution
```

---

# Match Expressions

Unlike NodeSelector, Required Node Affinity uses **matchExpressions**.

Example:

```yaml
matchExpressions:
- key: disktype
  operator: In
  values:
  - ssd
```

This means:

```
Node Label

disktype
must equal
ssd
```

---

# Supported Operators

## In

Matches one or more specified values.

Example:

```yaml
operator: In
values:
- ssd
```

Meaning:

Only SSD nodes.

---

## NotIn

Rejects specified values.

Example:

```yaml
operator: NotIn
values:
- hdd
```

Meaning:

Schedule anywhere except HDD nodes.

---

## Exists

Checks whether the label exists.

Example:

```yaml
operator: Exists
```

The label value does not matter.

---

## DoesNotExist

Schedules only if the label is absent.

---

## Gt

Greater Than.

Example:

```yaml
operator: Gt
values:
- "4"
```

Used mainly for numeric labels.

---

## Lt

Less Than.

Works similarly to Gt.

---

# Lab Setup

Assign labels.

Worker1

```bash
kubectl label node worker1 disktype=ssd region=east
```

Worker2

```bash
kubectl label node worker2 disktype=ssd region=west
```

Worker3

```bash
kubectl label node worker3 disktype=hdd region=east
```

Verify.

```bash
kubectl get nodes --show-labels
```

---

# Lab 1 – Required Affinity

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-required
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-required
  template:
    metadata:
      labels:
        app: nginx-required
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

      containers:
      - name: nginx
        image: nginx
```

Deploy.

```bash
kubectl apply -f nginx-required.yaml
```

Verify.

```bash
kubectl get pods -o wide
```

Expected:

Pods run only on:

- worker1
- worker2

---

# Lab 2 – Region East

Change:

```yaml
key: region

values:

- east
```

Expected:

Pods run only on:

- worker1
- worker3

---

# Lab 3 – AND Condition

Example:

```yaml
matchExpressions:

- key: disktype
  operator: In
  values:
  - ssd

- key: region
  operator: In
  values:
  - east
```

This means:

```
SSD

AND

Region East
```

Expected:

Only

```
worker1
```

---

# Lab 4 – Avoid HDD

```yaml
operator: NotIn

values:

- hdd
```

Expected:

Pods run only on:

- worker1
- worker2

---

# What Happens if No Node Matches?

Change:

```yaml
values:

- nvme
```

Deploy.

```bash
kubectl get pods
```

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

didn't match Pod's node affinity/selector
```

---

# Production Example

Cluster:

| Node | Labels |
|-------|---------|
| worker1 | database=true |
| worker2 | web=true |
| worker3 | monitoring=true |

MySQL Deployment

```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
  - matchExpressions:
    - key: database
      operator: In
      values:
      - "true"
```

Result:

MySQL always runs on the database node.

---

# Troubleshooting

## Pod Stuck in Pending

Check:

```bash
kubectl describe pod <pod-name>
```

Look for:

```
didn't match Pod's node affinity/selector
```

---

## Verify Labels

```bash
kubectl get nodes --show-labels
```

---

## Verify Affinity

```bash
kubectl describe pod <pod-name>
```

---

## Verify Placement

```bash
kubectl get pods -o wide
```

---

# Best Practices

- Use meaningful Node Labels.
- Keep affinity rules simple.
- Prefer labels that describe hardware or purpose.
- Document custom labels used in production.
- Test scheduling rules before production deployment.

---

# Common Mistakes

### Mistake 1

Confusing NodeSelector with Node Affinity.

NodeSelector supports only exact matching.

Node Affinity supports advanced scheduling.

---

### Mistake 2

Forgetting that Required Affinity is a hard rule.

No matching node means:

```
Pending
```

---

### Mistake 3

Using incorrect label keys.

Always verify labels.

```bash
kubectl get nodes --show-labels
```

---

# Interview Questions

### What is Required Node Affinity?

A scheduling rule that requires a Pod to run only on Nodes that match specified label expressions.

---

### What happens if no Node matches?

The Pod remains in the Pending state.

---

### What does IgnoredDuringExecution mean?

The affinity rule is evaluated only during scheduling. Kubernetes does not evict a running Pod if the Node's labels change later.

---

### Name the supported operators.

- In
- NotIn
- Exists
- DoesNotExist
- Gt
- Lt

---

### Can Required Node Affinity replace NodeSelector?

Yes.

It is more flexible and supports advanced scheduling rules.
