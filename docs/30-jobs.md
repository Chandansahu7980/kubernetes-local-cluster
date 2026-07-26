# Kubernetes Jobs

# 🧠 What is a Kubernetes Job?

A **Job** is a Kubernetes workload designed to execute a **finite task**.

Unlike a Deployment, a Job **does not keep Pods running forever**.

Instead, it creates Pods until the required task has been completed successfully.

Examples:

- Database backup
- Log processing
- Report generation
- Data migration
- Sending emails
- Running scripts
- CI/CD build steps

---

# Why Do We Need Jobs?

Imagine you need to:

- Generate a PDF
- Backup a database
- Process 10,000 images
- Import CSV data

These tasks only need to run **once**.

Keeping a Pod alive forever would waste resources.

Jobs solve this problem.

---

# Deployment vs Job

| Deployment | Job |
|------------|-----|
| Long-running applications | One-time tasks |
| Keeps Pods running | Stops after work is complete |
| Restarts Pods forever | Stops after successful completion |
| Example: Nginx | Example: Backup Script |

---

# Job Architecture

```text
                Job
                  │
                  ▼
          Job Controller
                  │
                  ▼
              Creates Pod
                  │
                  ▼
          Executes Container
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
   Exit Code = 0      Exit Code ≠ 0
        │                   │
        ▼                   ▼
 Job Successful         Retry (if allowed)
```

---

# Simple Job Example

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hello
        image: busybox
        command:
        - echo
        - "Hello Kubernetes"
```

Apply:

```bash
kubectl apply -f hello-job.yaml
```

---

# Job Lifecycle

```text
Create Job
      │
      ▼
Create Pod
      │
      ▼
Run Command
      │
      ▼
Command Finished
      │
      ▼
Exit Code
      │
      ▼
Job Completed
```

---

# Exit Codes

Jobs determine success using the Linux exit code.

| Exit Code | Meaning |
|-----------|----------|
| 0 | Success |
| Non-zero | Failure |

---

# restartPolicy

Controls container restart behaviour.

## Never

```yaml
restartPolicy: Never
```

If the Pod fails:

```text
Pod Fails

↓

Job creates NEW Pod
```

This is the most common option for Jobs.

---

## OnFailure

```yaml
restartPolicy: OnFailure
```

If the container fails:

```text
Container Fails
  ↓
Kubelet restarts container
  ↓
Same Pod
```

---

# backoffLimit

Specifies how many retries Kubernetes performs after the initial failure.

Example:

```yaml
backoffLimit: 3
```

Execution:

```text
Initial Pod
  ↓
Fail
  ↓
Retry 1
  ↓
Retry 2
  ↓
Retry 3
  ↓
Job Failed
```

Total Pods created:

```text
1 Initial Pod
+
3 Retry Pods
=
4 Pods
```

Default:

```yaml
backoffLimit: 6
```

---

# completions

Defines how many successful task executions are required.

Example:

```yaml
completions: 5
```

Meaning:

```text
Need

5 Successful Pods
```

---

# parallelism

Defines how many Pods may run simultaneously.

Example:

```yaml
parallelism: 2
```

Meaning:

```text
Only 2 Pods

Running Together
```

---

# completions vs parallelism

| completions | parallelism | Behaviour |
|-------------|-------------|-----------|
| 5 | 1 | Run Pods one by one until 5 succeed |
| 5 | 2 | Run 2 Pods simultaneously until 5 succeed |
| 10 | 5 | Run up to 5 Pods together until 10 succeed |

---

# Example Timeline

```text
Need 5 Successful Pods

Parallelism = 2

Start:

Pod1
Pod2

↓

Complete

↓

Pod3
Pod4

↓

Complete

↓

Pod5

↓

Job Complete
```

---

# ttlSecondsAfterFinished

Automatically deletes completed Jobs and Pods.

Example:

```yaml
ttlSecondsAfterFinished: 60
```

Meaning:

```text
Job Completes
  ↓
Wait 60 Seconds
  ↓
Delete Job
  ↓
Delete Pod
```

Useful for CronJobs and production clusters.

---

# Complete Production Example

```yaml
apiVersion: batch/v1
kind: Job

metadata:
  name: production-job

spec:
  completions: 5
  parallelism: 2
  backoffLimit: 3
  ttlSecondsAfterFinished: 60
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          echo "Job Started"
          sleep 10
          echo "Job Finished"
        resources:
          requests:
            cpu: "100m"
            memory: "64Mi"
          limits:
            cpu: "250m"
            memory: "128Mi"
```

---

# Useful Commands

Create Job

```bash
kubectl apply -f job.yaml
```

View Jobs

```bash
kubectl get jobs
```

Describe Job

```bash
kubectl describe job <job-name>
```

View Pods

```bash
kubectl get pods
```

View Logs

```bash
kubectl logs <pod-name>
```

Delete Job

```bash
kubectl delete job <job-name>
```

---

# Common Issues

## Job Keeps Creating Pods

Cause:

- Container exits with non-zero exit code

Check:

```bash
kubectl describe job <job-name>
```

Look for:

```text
BackoffLimitExceeded
```

---

## Pod Status = StartError

Cause:

Incorrect command format.

Incorrect:

```yaml
command:
- kubectl version --client
```

Correct:

```yaml
command:
- kubectl
- version
- --client
```

---

## Job Never Completes

Possible reasons:

- Container never exits
- Infinite loop
- Application hanging

Check:

```bash
kubectl logs <pod-name>
```

---

## Job Shows 0/1

Meaning:

Required completion:

```text
1
```

Successful completion:

```text
0
```

The Job has not yet completed successfully.

---

# Real-World Use Cases

- Database backup
- Database restore
- Log cleanup
- Sending scheduled emails
- Data migration
- Report generation
- Machine learning batch processing
- Video transcoding
- CI/CD build pipelines

---

# Interview Questions

### Why not use a Deployment for backups?

Because Deployments continuously maintain running Pods, whereas backups are finite tasks that should stop after completion.

---

### What determines whether a Job succeeds?

The container's exit code.

Exit Code:

```text
0
```

means success.

---

### What is the default backoffLimit?

```text
6
```

---

### Difference between completions and parallelism?

**completions**

Total successful task executions required.

**parallelism**

Maximum Pods allowed to run simultaneously.

---

### What does ttlSecondsAfterFinished do?

Automatically deletes completed or failed Jobs and their Pods after the specified time.

---

# Best Practices

- Use `restartPolicy: Never` for most batch workloads.
- Pin image versions (avoid `latest` in production).
- Set appropriate `resources.requests` and `resources.limits`.
- Configure `backoffLimit` based on application requirements.
- Use `ttlSecondsAfterFinished` to keep clusters clean.
- Monitor Job logs and events for troubleshooting.

---

# Key Learnings

- Job = One-time or batch workload.
- Jobs stop after successful completion.
- Success is determined by the container exit code.
- `backoffLimit` controls retries.
- `completions` defines how many successful executions are needed.
- `parallelism` controls concurrent Pods.
- `ttlSecondsAfterFinished` automatically cleans up Jobs.
- Jobs are ideal for backups, reports, migrations, and batch processing.