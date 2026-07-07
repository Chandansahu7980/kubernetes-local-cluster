# Kubernetes Readiness Probe

## Overview

A Readiness Probe is a Kubernetes health check that determines whether a Pod is ready to receive traffic.

Unlike a Liveness Probe, a Readiness Probe **does not restart the container**. Instead, it informs Kubernetes whether the Pod should be included in the Service's endpoints.

If the probe fails:

- Pod remains Running
- Container is NOT restarted
- Pod is marked **Not Ready**
- Service stops sending traffic to the Pod

Once the probe succeeds again, Kubernetes automatically adds the Pod back to the Service.

---

# Why Do We Need Readiness Probe?

Imagine an application with three replicas.

```text
                Service
                   |
        -----------------------
        |         |          |
      Pod-1     Pod-2      Pod-3
```

Suppose Pod-2 loses database connectivity.

Without a Readiness Probe:

```text
Service
   |
   +---- Pod-1 (Healthy)
   +---- Pod-2 (Broken)
   +---- Pod-3 (Healthy)
```

Users may randomly receive errors because traffic is still sent to the unhealthy Pod.

With a Readiness Probe:

```text
Service
   |
   +---- Pod-1 (Healthy)
   +---- Pod-3 (Healthy)
```

Pod-2 is automatically removed from the Service until it becomes healthy again.

This prevents users from experiencing application errors.

---

# How Readiness Probe Works

Application lifecycle:

```text
Container Starts
       |
       ▼
Readiness Probe Executes
       |
       ├──────── Success ───────► Pod becomes Ready
       │
       └──────── Failure ───────► Pod becomes Not Ready
                                      │
                                      ▼
                           Removed from Service Endpoints
```

The container continues running even if the readiness check fails.

---

# Readiness Probe vs Liveness Probe

| Feature | Readiness Probe | Liveness Probe |
|----------|-----------------|----------------|
| Removes Pod from Service | ✅ Yes | ❌ No |
| Restarts Container | ❌ No | ✅ Yes |
| Pod Status | Running | Running (until restart) |
| Main Purpose | Control traffic | Self-healing |

---

# Readiness Probe Configuration

Example:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80

  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```

---

# Understanding Each Parameter

## httpGet

Checks the HTTP response from the application.

```yaml
httpGet:
  path: /
  port: 80
```

Kubernetes expects an HTTP response code between **200 and 399**.

---

## initialDelaySeconds

```yaml
initialDelaySeconds: 5
```

Waits before performing the first health check.

Useful for applications that need time to start.

---

## periodSeconds

```yaml
periodSeconds: 5
```

Runs the probe every 5 seconds.

---

## timeoutSeconds

```yaml
timeoutSeconds: 2
```

Waits up to 2 seconds for the application to respond.

If no response is received, the probe fails.

---

## failureThreshold

```yaml
failureThreshold: 3
```

Number of consecutive failed probes before Kubernetes marks the Pod as **Not Ready**.

---

# Practical Lab

## Step 1

Deploy PHP application with two replicas.

```bash
kubectl scale deployment php-deployment --replicas=2 -n pro2
```

---

## Step 2

Verify Pods.

```bash
kubectl get pods -n pro2
```

Example:

```text
NAME                              READY   STATUS
php-deployment-xxxx               1/1     Running
php-deployment-yyyy               1/1     Running
```

---

## Step 3

Verify Service endpoints.

```bash
kubectl get endpoints php-service -n pro2
```

Example:

```text
php-service
10.244.1.5:80
10.244.2.6:80
```

Both Pods receive traffic.

---

## Step 4

Add Readiness Probe.

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80

  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```

Apply changes.

---

## Step 5

Watch rollout.

```bash
kubectl get pods -n pro2 -w
```

Observe:

```text
READY

0/1
↓

1/1
```

The Pod becomes Ready only after the probe succeeds.

---

## Step 6

Break the application.

Login to the container.

```bash
kubectl exec -it <pod-name> -n pro2 -- bash
```

Rename the home page.

```bash
mv /var/www/html/index.php /var/www/html/index.php.bak
```

Exit the container.

---

## Step 7

Observe Pod status.

```bash
kubectl get pods -n pro2
```

Result:

```text
READY

0/1
```

Notice:

```text
STATUS

Running
```

The container is still running.

---

## Step 8

Check Service endpoints.

```bash
kubectl get endpoints php-service -n pro2
```

One Pod disappears from the endpoint list.

Example:

Before:

```text
10.244.1.5:80
10.244.2.6:80
```

After:

```text
10.244.2.6:80
```

Traffic is automatically redirected to healthy Pods.

---

## Step 9

Verify Restart Count.

```bash
kubectl describe pod <pod-name> -n pro2
```

Look for:

```text
Restart Count: 0
```

The Pod was **not restarted**.

---

## Step 10

Restore the application.

```bash
kubectl exec -it <pod-name> -n pro2 -- bash
```

Restore the file.

```bash
mv /var/www/html/index.php.bak /var/www/html/index.php
```

Wait a few seconds.

Check Pods.

```bash
kubectl get pods -n pro2
```

Result:

```text
READY

1/1
```

Check endpoints again.

```bash
kubectl get endpoints php-service -n pro2
```

The Pod is automatically added back to the Service.

---

# Useful Commands

View Pods.

```bash
kubectl get pods -n pro2
```

Watch Pods.

```bash
kubectl get pods -w -n pro2
```

Describe Pod.

```bash
kubectl describe pod <pod-name> -n pro2
```

Check endpoints.

```bash
kubectl get endpoints php-service -n pro2
```

View Deployment.

```bash
kubectl describe deployment php-deployment -n pro2
```

---

# Common Issues

## 1. Readiness Probe Never Succeeds

Symptoms:

```text
READY
0/1
```

Possible causes:

- Wrong path
- Wrong port
- Application not listening
- Slow startup

Verify:

```bash
kubectl describe pod <pod-name>
```

---

## 2. Incorrect Path

Example:

```yaml
path: /health
```

But application only serves:

```text
/
```

The probe always fails.

Verify manually.

```bash
kubectl exec -it <pod-name> -- curl http://localhost/
```

---

## 3. Wrong Port

Example:

```yaml
port: 8080
```

Application actually listens on:

```text
80
```

Verify:

```bash
kubectl exec -it <pod-name> -- netstat -tlnp
```

or

```bash
kubectl exec -it <pod-name> -- ss -tln
```

---

## 4. Application Takes Longer to Start

Increase:

```yaml
initialDelaySeconds
```

or use a **Startup Probe**.

---

## 5. Probe Timeout

Increase:

```yaml
timeoutSeconds
```

for slow applications.

---

# Troubleshooting Commands

Describe Pod.

```bash
kubectl describe pod <pod-name>
```

View Events.

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

View logs.

```bash
kubectl logs <pod-name>
```

Test application manually.

```bash
kubectl exec -it <pod-name> -- curl http://localhost/
```

Check endpoints.

```bash
kubectl get endpoints
```

---

# Best Practices

- Use a lightweight endpoint such as `/health` instead of `/`.
- Avoid checking database connectivity in the readiness endpoint unless the application truly cannot function without it.
- Keep probe responses fast.
- Configure appropriate `initialDelaySeconds` for slow-starting applications.
- Use Readiness Probes together with Liveness Probes for production workloads.

---

# Key Takeaways

- Readiness Probe determines if a Pod is ready to receive traffic.
- It **does not restart** the container.
- Failed Pods are removed from the Service endpoints.
- Healthy Pods continue serving requests.
- When the probe succeeds again, Kubernetes automatically restores traffic to the Pod.

---

# Interview Questions

### What is a Readiness Probe?

A Readiness Probe determines whether a Pod is ready to receive traffic. If it fails, Kubernetes removes the Pod from the Service endpoints without restarting the container.

---

### Does a Readiness Probe restart a Pod?

No. It only controls whether the Pod receives traffic.

---

### What happens when a Readiness Probe fails?

- Pod remains Running.
- Pod becomes Not Ready.
- Service stops routing traffic to the Pod.
- Container is not restarted.

---

### Difference between Readiness and Liveness Probe?

- Readiness controls traffic.
- Liveness provides self-healing by restarting unhealthy containers.