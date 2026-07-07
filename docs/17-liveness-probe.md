# Kubernetes Liveness Probe

# Overview

A **Liveness Probe** is a Kubernetes health check used to determine whether a container is still healthy and functioning correctly.

If the Liveness Probe fails repeatedly, Kubernetes assumes that the application has become unhealthy or stuck and automatically **restarts the container**.

This feature is one of the core reasons Kubernetes is called a **self-healing platform**.

---

# Why Do We Need a Liveness Probe?

Imagine a PHP application running inside a Pod.

```
Browser
   │
Ingress
   │
Service
   │
PHP Pod
```

Initially everything works correctly.

After several hours:

- Apache process is still running.
- Container is still running.
- Pod status is Running.
- But the application has stopped responding because of a memory leak or deadlock.

Without a Liveness Probe:

```
Pod Status: Running

Application:
❌ Not Responding
```

Kubernetes does not know that the application is unhealthy because the container process still exists.

Users continue receiving errors.

---

# How Liveness Probe Solves This

Kubernetes periodically checks the application.

```
Liveness Probe
        │
        ▼
HTTP GET /healthz.php
```

If the application responds successfully:

```
HTTP 200 OK
```

Nothing happens.

If the application does not respond or returns an error:

```
HTTP 500
```

After the configured number of failures:

```
Container Restarted
```

No manual intervention is required.

---

# Readiness vs Liveness

| Feature | Readiness Probe | Liveness Probe |
|----------|-----------------|----------------|
| Removes Pod from Service | ✅ Yes | ❌ No |
| Restarts Container | ❌ No | ✅ Yes |
| Used for Traffic Control | ✅ Yes | ❌ No |
| Used for Self-Healing | ❌ No | ✅ Yes |

---

# How Liveness Probe Works

```
Application Running
        │
        ▼
Liveness Probe Executes
        │
        ├──────── Success ───────► Continue Running
        │
        └──────── Failure
                  │
                  ▼
Failure Count Increases
                  │
                  ▼
Failure Threshold Reached
                  │
                  ▼
Container Restarted
```

---

# Liveness Probe Configuration

Example:

```yaml
livenessProbe:
  httpGet:
    path: /healthz.php
    port: 80

  initialDelaySeconds: 20
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

---

# Understanding Each Parameter

## httpGet

```yaml
httpGet:
  path: /healthz.php
  port: 80
```

Kubernetes sends an HTTP GET request to:

```
http://<Pod-IP>:80/healthz.php
```

Expected response:

```
HTTP 200
```

---

## initialDelaySeconds

```yaml
initialDelaySeconds: 20
```

Wait before performing the first health check.

Useful when the application needs time to start.

---

## periodSeconds

```yaml
periodSeconds: 10
```

Run the health check every 10 seconds.

---

## timeoutSeconds

```yaml
timeoutSeconds: 2
```

Wait for a maximum of 2 seconds.

If no response is received, the probe fails.

---

## failureThreshold

```yaml
failureThreshold: 3
```

After three consecutive failures, Kubernetes restarts the container.

---

# Production Best Practice

Instead of checking the home page:

```
/
```

Create a dedicated endpoint.

Example:

```
healthz.php
```

Contents:

```php
<?php

http_response_code(200);

header('Content-Type: application/json');

echo json_encode([
    "status"=>"UP",
    "service"=>"php-crud-app"
]);

?>
```

The endpoint should only verify that:

- PHP is working
- Apache is running
- Application process is alive

It should **not** check the database.

---

# Why Not Check Database Here?

Suppose MySQL crashes.

Should Kubernetes restart Apache?

No.

Apache is healthy.

The database is not.

Instead:

```
Readiness Probe
```

should fail.

The Pod is removed from the Service.

Apache continues running.

This prevents unnecessary container restarts.

---

# Practical Lab

## Step 1

Scale PHP Deployment.

```bash
kubectl scale deployment php-deployment --replicas=2 -n pro2
```

---

## Step 2

Add Liveness Probe.

```yaml
livenessProbe:
  httpGet:
    path: /healthz.php
    port: 80

  initialDelaySeconds: 20
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

Apply the Deployment.

---

## Step 3

Watch Pods.

```bash
kubectl get pods -w -n pro2
```

Observe:

```
READY

1/1
```

---

## Step 4

Verify Liveness Probe.

```bash
kubectl describe pod <pod-name> -n pro2
```

Example:

```
Liveness:

http-get http://:80/healthz.php
```

---

## Step 5

Break the Health Endpoint.

Modify:

```
healthz.php
```

Replace with:

```php
<?php

http_response_code(500);

echo "BROKEN";

?>
```

Save the file.

---

## Step 6

Observe Pod.

```bash
kubectl get pods -w -n pro2
```

After a few failed checks:

```
Restart Count

1
```

Container automatically restarts.

---

## Step 7

Restore Health Endpoint.

Restore:

```php
<?php

http_response_code(200);

echo "OK";

?>
```

Container becomes healthy again.

---

# Verifying the Restart

Describe the Pod.

```bash
kubectl describe pod <pod-name>
```

Look for:

```
Restart Count

1
```

This confirms Kubernetes restarted the container.

---

# Viewing Previous Logs

View logs from the container before the restart.

```bash
kubectl logs <pod-name> --previous -n pro2
```

View current logs.

```bash
kubectl logs <pod-name> -n pro2
```

---

# Useful Commands

Watch Pods.

```bash
kubectl get pods -w
```

Describe Pod.

```bash
kubectl describe pod <pod-name>
```

View Events.

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

View Current Logs.

```bash
kubectl logs <pod-name>
```

View Previous Logs.

```bash
kubectl logs <pod-name> --previous
```

---

# Common Issues

## 1. Wrong Path

Example:

```yaml
path: /health
```

But the application exposes:

```
/healthz.php
```

Result:

```
404
```

Container keeps restarting.

---

## 2. Wrong Port

Application:

```
80
```

Probe:

```
8080
```

Result:

```
Connection Refused
```

---

## 3. Failure Threshold Too Low

Example:

```yaml
failureThreshold: 1
```

Temporary slow responses may trigger unnecessary restarts.

Increase:

```yaml
failureThreshold: 3
```

or higher if appropriate.

---

## 4. Startup Takes Too Long

If the application needs 60 seconds to start but the Liveness Probe begins after 20 seconds, Kubernetes may restart it before startup completes.

Solution:

- Increase `initialDelaySeconds`
- Or use a **Startup Probe**

---

## 5. Health Endpoint Checks Database

Avoid:

```
healthz.php
```

connecting to MySQL.

If the database is temporarily unavailable:

```
Apache Healthy
Database Down
```

Kubernetes repeatedly restarts the container unnecessarily.

Instead:

- Liveness checks application health.
- Readiness checks application dependencies.

---

# Troubleshooting Commands

Describe Pod.

```bash
kubectl describe pod <pod-name>
```

Check Events.

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

View Previous Logs.

```bash
kubectl logs <pod-name> --previous
```

Execute into Pod.

```bash
kubectl exec -it <pod-name> -- bash
```

Test Health Endpoint.

```bash
curl http://localhost/healthz.php
```

Expected:

```
HTTP 200
```

---

# Best Practices

- Use a lightweight health endpoint.
- Keep the endpoint fast.
- Do not check database connectivity.
- Return only application health.
- Use Readiness and Liveness together.
- Monitor Restart Count to identify recurring failures.

---

# Key Takeaways

- Liveness Probe provides Kubernetes self-healing.
- It continuously monitors application health.
- Failed probes trigger automatic container restarts.
- The Pod usually keeps the same identity while the container is recreated.
- Use a dedicated endpoint such as `/healthz.php` for reliable health checks.

---

# Interview Questions

## What is a Liveness Probe?

A Liveness Probe is a health check that allows Kubernetes to determine whether a container is still healthy. If the probe fails repeatedly, Kubernetes restarts the container automatically.

---

## What happens when a Liveness Probe fails?

- Kubernetes marks the container as unhealthy.
- After the configured failure threshold, the container is terminated.
- Kubernetes starts a new container according to the Pod's restart policy.

---

## Does a Liveness Probe remove a Pod from the Service?

No. Its primary purpose is to restart unhealthy containers. If a Readiness Probe is also configured and begins failing during the restart process, the Pod may temporarily stop receiving traffic until it becomes Ready again.

---

## Why should Liveness and Readiness use different endpoints?

Because they answer different questions:

- **Liveness**: "Is the application process alive?"
- **Readiness**: "Is the application ready to serve user requests?"

Separating the endpoints avoids unnecessary restarts and allows Kubernetes to make the correct decision.

---

# Learning Summary

In this lab we learned:

- Why Kubernetes needs a Liveness Probe.
- How Kubernetes performs self-healing.
- How to create a dedicated `/healthz.php` endpoint.
- The difference between Liveness and Readiness.
- How Kubernetes restarts unhealthy containers automatically.
- Best practices for implementing health checks in production environments.