# Horizontal Pod Autoscaler (HPA)

This document explains how to configure and use **Horizontal Pod Autoscaler (HPA)** in Kubernetes, including Metrics Server installation, CPU and memory-based autoscaling, HPA YAML configuration, load testing, troubleshooting, and important HPA behavior.

---

## 📌 What is HPA?

**Horizontal Pod Autoscaler (HPA)** automatically adjusts the number of Pod replicas in a workload based on resource utilization or other supported metrics.

```text
Low Load
   ↓
Fewer Pods

High Load
   ↓
More Pods
```

For example:

```text
1 Pod → 2 Pods → 3 Pods
```

When the load decreases:

```text
3 Pods → 2 Pods → 1 Pod
```

---

# 🧠 HPA Architecture

For CPU and memory-based HPA:

```text
Pod
 │
 │ CPU / Memory usage
 ▼
Kubelet
 │
 ▼
Metrics Server
 │
 ▼
Metrics API
 │
 ▼
HPA Controller
 │
 │ Calculate desired replicas
 ▼
Deployment
 │
 ▼
ReplicaSet
 │
 ▼
Pods
```

---

# 1. Metrics Server

HPA needs resource metrics such as:

* CPU usage
* Memory usage

Our local Kubernetes cluster did not initially have Metrics Server installed.

The following commands confirmed this:

```bash
kubectl top nodes
kubectl top pods -A
```

Expected error:

```text
error: Metrics API not available
```

Check whether the Metrics API exists:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

If it is not installed:

```text
Error from server (NotFound)
```

You can also check the Metrics API directly:

```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

---

# 2. Install Metrics Server

Install Metrics Server:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Check the Deployment:

```bash
kubectl get deployment metrics-server -n kube-system
```

Check the Pod:

```bash
kubectl get pods -n kube-system | grep metrics
```

Check the APIService:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

---

# 3. Metrics Server Troubleshooting

Metrics Server state 1/0 with Running. Log contained below error:

```text
x509: cannot validate certificate for 192.168.56.12 because it doesn't contain any IP SANs
```

Similar errors were seen for the other nodes.

Example:

```text
Failed to scrape node

Get "https://192.168.56.12:10250/metrics/resource":
x509: cannot validate certificate for 192.168.56.12
because it doesn't contain any IP SANs
```

This means Metrics Server was reaching kubelet but could not validate the kubelet certificate using the node IP.

---

## 3.1 Check Metrics Server Logs

```bash
kubectl logs -n kube-system deployment/metrics-server
```

Look for errors such as:

```text
Failed to scrape node
x509: cannot validate certificate
```

---

## 3.2 Local Lab Fix

For our local learning cluster, we used:

```text
--kubelet-insecure-tls
```

This tells Metrics Server not to verify the kubelet serving certificate.

> ⚠️ This is useful for a local learning environment but should not automatically be considered the production solution.

Check the Metrics Server arguments:

```bash
kubectl get deployment metrics-server \
  -n kube-system \
  -o yaml
```

Look under:

```yaml
spec:
  template:
    spec:
      containers:
      - name: metrics-server
        args:
```

You should see:

```text
--kubelet-insecure-tls
```

---

# 4. Verify Metrics API

Once Metrics Server is working:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

Then:

```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

Finally:

```bash
kubectl top nodes
```

```bash
kubectl top pods -A
```

Example:

```text
NAME      CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master    120m         4%     850Mi           21%
worker1   80m          4%     700Mi           34%
worker2   70m          3%     650Mi           31%
```

If `kubectl top` works, the Metrics API is available.

---

# 5. Important Difference: Metrics Server vs HPA

Metrics Server is **not HPA**.

```text
Metrics Server
    ↓
Provides resource metrics

HPA
    ↓
Consumes metrics
and changes Pod replicas
```

Metrics Server can be checked using:

```bash
kubectl top nodes
kubectl top pods -A
```

HPA can be checked using:

```bash
kubectl get hpa
```

---

# 6. Create an Application for HPA

Example Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: hpa-lab
spec:
  replicas: 1
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
        image: nginx:1.27
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        ports:
        - containerPort: 80
```

Apply:

```bash
kubectl apply -f hpa-deployment.yaml
```

Check:

```bash
kubectl get pods -n hpa-lab
```

And:

```bash
kubectl top pods -n hpa-lab
```

---

# 7. Why Resource Requests Matter

For utilization-based HPA, Kubernetes compares resource usage against the resource **request**.

For example:

```yaml
resources:
  requests:
    cpu: 100m
```

If the Pod uses:

```text
50m CPU
```

then:

```text
50 / 100 × 100 = 50%
```

Therefore:

```text
CPU utilization = 50%
```

The same applies to memory.

For example:

```yaml
requests:
  memory: 128Mi
```

If the Pod uses:

```text
32Mi
```

then:

```text
32 / 128 × 100 = 25%
```

---

# 8. CPU-Based HPA

A quick way to create an HPA:

```bash
kubectl autoscale deployment nginx \
  --cpu-percent=50 \
  --min=1 \
  --max=3 \
  -n hpa-lab
```

Check:

```bash
kubectl get hpa -n hpa-lab
```

Example:

```text
NAME    REFERENCE          TARGETS   MINPODS   MAXPODS   REPLICAS
nginx   Deployment/nginx   0%/50%    1         3         1
```

The output:

```text
0%/50%
```

means:

```text
Current CPU utilization / Target CPU utilization
```

---

# 9. HPA YAML

For GitOps and declarative Kubernetes configuration, define HPA using YAML.

Example:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler

metadata:
  name: nginx-hpa
  namespace: hpa-lab

spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx

  minReplicas: 1
  maxReplicas: 3

  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

Apply:

```bash
kubectl apply -f hpa.yaml
```

Check:

```bash
kubectl get hpa -n hpa-lab
```

Detailed information:

```bash
kubectl describe hpa nginx-hpa -n hpa-lab
```

---

# 10. Understanding `scaleTargetRef`

```yaml
scaleTargetRef:
  apiVersion: apps/v1
  kind: Deployment
  name: nginx
```

This tells HPA:

```text
Control the replica count of
Deployment/nginx
```

---

# 11. CPU + Memory HPA

HPA can use multiple resource metrics.

Example:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler

metadata:
  name: nginx-hpa
  namespace: hpa-lab

spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx

  minReplicas: 1
  maxReplicas: 3

  metrics:

  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50

  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

Now HPA monitors:

```text
CPU    → 50%
Memory → 70%
```

Example:

```text
CPU    = 37% / 50%
Memory = 2% / 70%
```

This means:

```text
CPU:
37% current
50% target

Memory:
2% current
70% target
```

---

# 12. Important Memory HPA Issue

If you configure:

```yaml
averageUtilization: 70
```

for memory but the Deployment doesn't define:

```yaml
resources:
  requests:
    memory: 128Mi
```

HPA may show:

```text
<unknown>/70%
```

For example:

```text
TARGETS
37%/50%, <unknown>/70%
```

Even though:

```bash
kubectl top pods
```

shows memory usage.

Why?

Because Metrics Server knows:

```text
Actual memory usage = 18Mi
```

but HPA cannot calculate utilization without a memory request.

Correct configuration:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi

  limits:
    cpu: 500m
    memory: 256Mi
```

Then HPA can calculate:

```text
Memory utilization =
Memory usage / Memory request × 100
```

---

# 13. HPA Decision Algorithm

The basic HPA calculation can be represented as:

```text
desiredReplicas =
ceil(
  currentReplicas ×
  currentMetric / targetMetric
)
```

Example:

```text
Current replicas = 1
Current CPU       = 80%
Target CPU        = 50%
```

Calculation:

```text
ceil(1 × 80 / 50)

= ceil(1.6)

= 2
```

HPA therefore recommends:

```text
1 Pod → 2 Pods
```

---

## Example: Scale Up

```text
Current replicas = 2
CPU utilization  = 100%
Target            = 50%
```

```text
ceil(2 × 100 / 50)
= ceil(4)
= 4
```

Desired replicas:

```text
4
```

---

## Example: Scale Down

```text
Current replicas = 3
CPU utilization  = 20%
Target            = 50%
```

```text
ceil(3 × 20 / 50)
= ceil(1.2)
= 2
```

HPA may recommend:

```text
3 → 2
```

---

# 14. Multiple Metrics

When multiple metrics are configured, HPA evaluates each metric.

Example:

```text
CPU recommendation:
2 Pods

Memory recommendation:
4 Pods
```

HPA uses the recommendation requiring more replicas:

```text
Desired replicas = 4
```

Therefore:

```text
CPU
 ↓
2 Pods

Memory
 ↓
4 Pods

HPA
 ↓
4 Pods
```

---

# 15. HPA Behavior

HPA can control how aggressively scaling occurs.

Example:

```yaml
behavior:

  scaleUp:
    stabilizationWindowSeconds: 0

    policies:
    - type: Percent
      value: 100
      periodSeconds: 60

  scaleDown:
    stabilizationWindowSeconds: 300

    policies:
    - type: Percent
      value: 50
      periodSeconds: 60
```

---

# 16. `stabilizationWindowSeconds`

Scale-down:

```yaml
stabilizationWindowSeconds: 300
```

means:

```text
300 seconds = 5 minutes
```

This prevents HPA from reacting too aggressively to short-lived changes.

It helps avoid:

```text
3 Pods
 ↓
2 Pods
 ↓
3 Pods
 ↓
2 Pods
```

This behavior is commonly called **flapping**.

Important:

```text
stabilizationWindowSeconds
```

does **not** mean:

```text
"Remove exactly one Pod every 5 minutes."
```

It controls stabilization of the scaling decision.

---

# 17. Scaling Policies

Example:

```yaml
scaleDown:
  policies:
  - type: Percent
    value: 50
    periodSeconds: 60
```

This controls how quickly replicas are allowed to decrease.

Think of the two settings separately:

```text
stabilizationWindowSeconds
        ↓
WHEN should HPA react?

policies
        ↓
HOW FAST can HPA change replicas?
```

---

# 18. Generate CPU Load

Expose the application:

```bash
kubectl expose deployment nginx \
  --name=nginx-service \
  --port=80 \
  --target-port=80 \
  -n hpa-lab
```

Create a load generator:

```bash
kubectl run load-generator \
  --image=busybox:1.36 \
  -n hpa-lab \
  -- /bin/sh -c \
  "while true; do wget -q -O- http://nginx-service; done"
```

---

# 19. Watch Autoscaling

Terminal 1:

```bash
kubectl get hpa -n hpa-lab -w
```

Terminal 2:

```bash
kubectl get pods -n hpa-lab -w
```

Terminal 3:

```bash
kubectl top pods -n hpa-lab
```

You may observe:

```text
CPU
 ↓
CPU usage increases
 ↓
Metrics Server observes usage
 ↓
HPA calculates desired replicas
 ↓
Deployment scales
 ↓
New Pods created
```

For example:

```text
1 Pod
 ↓
2 Pods
 ↓
3 Pods
```

---

# 20. Stop the Load

```bash
kubectl delete pod load-generator -n hpa-lab
```

Then monitor:

```bash
kubectl get hpa -n hpa-lab -w
```

and:

```bash
kubectl get pods -n hpa-lab -w
```

Eventually HPA can scale back toward:

```text
minReplicas: 1
```

Scale-down may take longer because HPA uses stabilization and scaling policies.

---

# 21. Useful HPA Commands

### List HPA

```bash
kubectl get hpa -A
```

```bash
kubectl get hpa -n hpa-lab
```

### Detailed HPA information

```bash
kubectl describe hpa nginx-hpa -n hpa-lab
```

### HPA YAML

```bash
kubectl get hpa nginx-hpa \
  -n hpa-lab \
  -o yaml
```

### HPA events

```bash
kubectl describe hpa nginx-hpa -n hpa-lab
```

Look for:

```text
AbleToScale
ScalingActive
ScalingLimited
SuccessfulRescale
```

### Watch HPA

```bash
kubectl get hpa -n hpa-lab -w
```

### Check resource usage

```bash
kubectl top nodes
```

```bash
kubectl top pods -n hpa-lab
```

### Check Metrics Server

```bash
kubectl get pods -n kube-system | grep metrics
```

```bash
kubectl logs -n kube-system deployment/metrics-server
```

### Check Metrics API

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

---

# 22. Common Problems

## ❌ Metrics API not available

```text
error: Metrics API not available
```

Check:

```bash
kubectl get pods -n kube-system | grep metrics
```

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

Check logs:

```bash
kubectl logs -n kube-system deployment/metrics-server
```

---

## ❌ `<unknown>` for memory

Example:

```text
37%/50%, <unknown>/70%
```

Check that the Deployment has a memory request:

```yaml
resources:
  requests:
    memory: 128Mi
```

---

## ❌ Metrics Server certificate error

Example:

```text
x509: cannot validate certificate for <node-ip>
because it doesn't contain any IP SANs
```

For a local learning cluster, check whether Metrics Server uses:

```text
--kubelet-insecure-tls
```

Check:

```bash
kubectl get deployment metrics-server \
  -n kube-system \
  -o yaml
```

---

## ❌ HPA doesn't scale

Check:

```bash
kubectl describe hpa nginx-hpa -n hpa-lab
```

Then verify:

```bash
kubectl top pods -n hpa-lab
```

Check resource requests:

```bash
kubectl get deployment nginx \
  -n hpa-lab \
  -o yaml
```

Also check:

```bash
kubectl get events -n hpa-lab --sort-by=.lastTimestamp
```

---

# 23. Important HPA Learning Points

```text
Metrics Server
    ↓
Provides CPU / Memory metrics

HPA
    ↓
Uses those metrics

Resource requests
    ↓
Required for utilization-based calculations

HPA
    ↓
Calculates desired replicas

Deployment
    ↓
Creates/removes Pods
```

Remember:

* **Metrics Server ≠ HPA**
* HPA uses the Metrics API
* CPU/memory utilization is calculated relative to resource requests
* `minReplicas` defines the lower boundary
* `maxReplicas` defines the upper boundary
* Multiple metrics can be configured
* HPA uses the metric recommendation requiring more replicas
* `behavior` controls scaling behavior
* `stabilizationWindowSeconds` helps prevent flapping
* Scaling policies control how quickly replica counts can change
* HPA does not necessarily scale immediately after a metric changes