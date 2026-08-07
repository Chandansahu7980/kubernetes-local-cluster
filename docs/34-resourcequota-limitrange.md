# Kubernetes ResourceQuota & LimitRange

This guide explains how Kubernetes controls resource usage inside a namespace using **ResourceQuota** and **LimitRange**. These two resources are commonly used together in production clusters to prevent resource exhaustion and enforce resource policies.

---

# Why Do We Need Them?

Imagine multiple teams sharing the same Kubernetes cluster.

Without restrictions:

- One team can consume all CPU and Memory.
- Other applications may fail to schedule.
- Cluster resources become unbalanced.

Kubernetes solves this using:

- **ResourceQuota** → Controls total resources consumed by a namespace.
- **LimitRange** → Controls resource limits for individual Pods/Containers.

---

# ResourceQuota

A **ResourceQuota** limits the total amount of resources that can be used within a namespace.

It can restrict:

- Number of Pods
- CPU Requests
- CPU Limits
- Memory Requests
- Memory Limits
- PVC count
- Storage usage
- ConfigMaps
- Secrets
- Services

---

# ResourceQuota Example

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: quota-lab
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 512Mi
    limits.cpu: "2"
    limits.memory: 1Gi
    pods: "3"
```

Apply:

```bash
kubectl apply -f quota.yaml
```

Verify:

```bash
kubectl get resourcequota -n quota-lab
```

Describe:

```bash
kubectl describe resourcequota team-quota -n quota-lab
```

Example:

```text
Resource         Used   Hard
--------         ----   ----
limits.cpu       0      2
limits.memory    0      1Gi
pods             0      3
requests.cpu     0      1
requests.memory  0      512Mi
```

---

# Understanding Used vs Hard

```text
Hard
│
├── Maximum resources allowed
│
Used
│
└── Currently consumed by Pods
```

Example:

```text
requests.cpu

Hard : 1 CPU
Used : 500m
```

Remaining:

```text
500m CPU
```

---

# Practical Lab

Create a Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod1
  namespace: quota-lab
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    resources:
      requests:
        cpu: "500m"
        memory: "256Mi"
      limits:
        cpu: "1"
        memory: "512Mi"
```

Apply:

```bash
kubectl apply -f pod1.yaml
```

Describe quota again:

```bash
kubectl describe quota team-quota -n quota-lab
```

Output:

```text
Resource         Used   Hard
--------         ----   ----
limits.cpu       1      2
limits.memory    512Mi  1Gi
pods             1      3
requests.cpu     500m   1
requests.memory  256Mi  512Mi
```

Notice how the Pod's declared requests and limits are reflected in the **Used** section.

---

# Quota Exceeded

Deploy another Pod until the namespace quota is exhausted.

When creating an additional Pod:

```bash
kubectl apply -f pod3.yaml
```

Example error:

```text
Error from server (Forbidden):
exceeded quota: team-quota
```

The Pod is rejected because the namespace has already reached its quota.

---

# Delete Pod and Free Resources

Delete a Pod:

```bash
kubectl delete pod pod1 -n quota-lab
```

Check quota:

```bash
kubectl describe quota team-quota -n quota-lab
```

The **Used** values decrease automatically, making resources available for new Pods.

---

# LimitRange

A **LimitRange** controls resource rules for individual Pods or Containers.

It can define:

- Default Requests
- Default Limits
- Minimum CPU
- Maximum CPU
- Minimum Memory
- Maximum Memory

Unlike ResourceQuota, it applies **per container**, not the entire namespace.

---

# LimitRange Example

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: quota-lab
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "250m"
      memory: "128Mi"
    max:
      cpu: "1"
      memory: "512Mi"
    min:
      cpu: "100m"
      memory: "64Mi"
```

Apply:

```bash
kubectl apply -f limitrange.yaml
```

Verify:

```bash
kubectl get limitrange -n quota-lab
```

Describe:

```bash
kubectl describe limitrange container-limits -n quota-lab
```

---

# Default Resources

Create a Pod **without** specifying any resources.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: default-resource-pod
  namespace: quota-lab
spec:
  containers:
  - name: nginx
    image: nginx:1.27
```

Apply:

```bash
kubectl apply -f default-resource-pod.yaml
```

Inspect:

```bash
kubectl get pod default-resource-pod -n quota-lab -o yaml
```

Kubernetes automatically injects:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

These values come from the **LimitRange**, not the Pod manifest.

---

# LimitRange Violation

Create a Pod exceeding the allowed limits.

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "256Mi"
  limits:
    cpu: "2"
    memory: "1Gi"
```

Apply:

```bash
kubectl apply -f limit-violation.yaml
```

Example:

```text
Error from server (Forbidden)
```

The Pod is rejected because it exceeds the maximum CPU and Memory allowed by the LimitRange.

---

# ResourceQuota vs LimitRange

| Feature | ResourceQuota | LimitRange |
|----------|---------------|------------|
| Scope | Namespace | Namespace |
| Controls | Total namespace resources | Individual container resources |
| Total CPU/Memory | ✅ | ❌ |
| Maximum CPU per container | ❌ | ✅ |
| Minimum CPU per container | ❌ | ✅ |
| Default Requests | ❌ | ✅ |
| Default Limits | ❌ | ✅ |
| Pod Count | ✅ | ❌ |

---

# Simple Analogy

Think of a company office.

### ResourceQuota

Company monthly budget.

```text
Total CPU = 8
Total Memory = 16Gi
```

Entire team cannot exceed this budget.

---

### LimitRange

Employee spending policy.

```text
Each employee:

Maximum Laptop Budget = ₹80,000
Minimum Laptop Budget = ₹40,000
```

Individual limits apply even if the company still has money left.

---

# Common Commands

Apply ResourceQuota

```bash
kubectl apply -f quota.yaml
```

Describe ResourceQuota

```bash
kubectl describe quota team-quota -n quota-lab
```

Apply LimitRange

```bash
kubectl apply -f limitrange.yaml
```

Describe LimitRange

```bash
kubectl describe limitrange container-limits -n quota-lab
```

View Namespace Resources

```bash
kubectl get all -n quota-lab
```

Delete Namespace

```bash
kubectl delete namespace quota-lab
```

---

# Common Mistakes

## Pod rejected due to ResourceQuota

Example:

```text
Error from server (Forbidden): exceeded quota
```

Cause:

Namespace has reached its CPU, Memory, or Pod limit.

Fix:

- Delete unused resources.
- Increase ResourceQuota.
- Reduce resource requests.

---

## Pod rejected due to LimitRange

Example:

```text
Error from server (Forbidden)
```

Cause:

Container requests or limits exceed the configured maximum or are below the minimum.

Fix:

Update the Pod's resource requests and limits to comply with the LimitRange.

---

## ResourceQuota not updating

Cause:

Resources still exist in the namespace.

Verify:

```bash
kubectl get all -n quota-lab
```

Delete unused Pods:

```bash
kubectl delete pod <pod-name> -n quota-lab
```

---

# Key Learnings

- ResourceQuota limits the **total resources** available to a namespace.
- LimitRange controls **resource rules for individual containers**.
- ResourceQuota tracks declared **requests** and **limits**, not actual runtime usage.
- Deleting a Pod automatically releases its quota.
- LimitRange can automatically apply default resource requests and limits.
- ResourceQuota and LimitRange are commonly used together in production Kubernetes clusters.
