# Kubernetes Startup Probe

## What is it?
A Startup Probe is a Kubernetes health check for applications that need extra time to start.

It tells Kubernetes:
- “The app is still starting.”
- “Do not run Readiness or Liveness checks yet.”

This prevents premature restarts.

## Why use it?
Use it for slow-starting apps such as:
- MySQL
- PostgreSQL
- Spring Boot
- Kafka
- Elasticsearch
- Jenkins

## Problem without Startup Probe
If Liveness starts too early:
- the app is not ready
- the probe fails
- Kubernetes restarts the container
- this can lead to CrashLoopBackOff

## How it works
1. Container starts
2. Startup Probe runs
3. If it keeps failing, Kubernetes waits until the limit is reached
4. Once it succeeds, Readiness and Liveness probes begin

## Example configuration
```yaml
startupProbe:
  httpGet:
    path: /healthz.php
    port: 80
  periodSeconds: 5
  failureThreshold: 20
```

## Important fields
- httpGet: checks an HTTP endpoint
- periodSeconds: how often Kubernetes checks
- failureThreshold: how many failures are allowed before restart

## Quick summary
- Startup Probe = wait for app startup
- Readiness Probe = allow traffic
- Liveness Probe = check if the app is still alive

Watch the Pods.

```bash
kubectl get pods -w -n pro2
```

Observe that the Pod reaches the Running and Ready state without being restarted prematurely.

---

## Step 5

Verify the Startup Probe.

```bash
kubectl describe pod <pod-name> -n pro2
```

Look for:

```
Startup:

http-get http://:80/healthz.php
```

---

# Challenge

## Experiment A

Remove the Startup Probe.

Keep:

```php
sleep(30);
```

Reduce the Liveness Probe delay.

```yaml
initialDelaySeconds: 5
```

Restart the Deployment.

Observe:

```
Restart Count

1

2

3

CrashLoopBackOff
```

Kubernetes continuously restarts the container because it assumes the application has failed.

---

## Experiment B

Re-enable the Startup Probe.

Restart the Deployment again.

Observe:

```
Startup Probe

↓

Application Ready

↓

Readiness Enabled

↓

Liveness Enabled

↓

No Restarts
```

This clearly demonstrates the purpose of the Startup Probe.

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

View Logs.

```bash
kubectl logs <pod-name>
```

View Previous Logs.

```bash
kubectl logs <pod-name> --previous
```

Restart Deployment.

```bash
kubectl rollout restart deployment php-deployment -n pro2
```

---

# Common Issues

## 1. Failure Threshold Too Low

Example:

```yaml
failureThreshold: 3
periodSeconds: 5
```

Maximum startup time:

```
15 seconds
```

Applications needing longer startup times will continuously restart.

---

## 2. Wrong Health Endpoint

Example:

```yaml
path: /health
```

Application exposes:

```
/healthz.php
```

Result:

```
404 Not Found
```

Startup never succeeds.

---

## 3. Wrong Port

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

## 4. Startup Probe Never Succeeds

Verify manually.

```bash
kubectl exec -it <pod-name> -- curl http://localhost/healthz.php
```

Expected:

```
HTTP 200
```

---

## 5. Forgetting to Remove sleep()

If you used:

```php
sleep(30);
```

for testing, remove it after completing the lab.

Leaving artificial delays in production is not recommended.

---

# Troubleshooting

Describe the Pod.

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

Test the endpoint.

```bash
curl http://localhost/healthz.php
```

Verify the Pod status.

```bash
kubectl get pods
```

---

# Best Practices

- Use Startup Probe only for applications with long startup times.
- Keep the Startup Probe lightweight.
- Configure an appropriate `failureThreshold` based on expected startup duration.
- Remove artificial startup delays after testing.
- Combine Startup, Readiness, and Liveness Probes for production applications.

---

# Real-World Examples

| Application | Startup Probe Recommended |
|-------------|---------------------------|
| PHP + Apache | Usually No |
| Nginx | Usually No |
| Node.js | Sometimes |
| Spring Boot | Yes |
| MySQL | Yes |
| PostgreSQL | Yes |
| Kafka | Yes |
| Elasticsearch | Yes |
| Jenkins | Yes |
| Oracle WebLogic | Yes |
| Oracle SOA Suite | Yes |

---

# Key Takeaways

- Startup Probe protects slow-starting applications from premature restarts.
- It runs only during application startup.
- Readiness and Liveness Probes begin only after the Startup Probe succeeds.
- Proper configuration prevents `CrashLoopBackOff` caused by slow initialization.
- Startup Probe is especially valuable for enterprise applications with long initialization times.

---

# Interview Questions

## What is a Startup Probe?

A Startup Probe is a health check that allows Kubernetes to determine whether an application has completed its startup process before enabling Readiness and Liveness Probes.

---

## Why was Startup Probe introduced?

It was introduced to prevent slow-starting applications from being restarted repeatedly by the Liveness Probe before they had enough time to initialize.

---

## When should Startup Probe be used?

Whenever an application requires a significant amount of time to start, such as databases, message brokers, search engines, or enterprise Java applications.

---

## Does Startup Probe run continuously?

No.

It runs only during application startup.

Once it succeeds, it is permanently disabled until the container restarts.

---

## Can Startup Probe restart a container?

Yes.

If the application fails to start within the configured time, Kubernetes restarts the container according to the Pod's restart policy.

---

# Learning Summary

In this lab we learned:

- Why Startup Probe was introduced.
- The limitations of using only Readiness and Liveness Probes.
- How Startup Probe prevents unnecessary restarts.
- How to simulate a slow-starting application.
- The complete lifecycle of Startup, Readiness, and Liveness Probes.
- Production best practices for implementing Kubernetes health checks.