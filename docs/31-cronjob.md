# Kubernetes CronJobs

This document explains **Kubernetes CronJobs**, how they automate recurring tasks, their relationship with Jobs, important scheduling options, concurrency policies, history management, and production best practices.
---

# 🧠 What is a CronJob?

A **CronJob** is a Kubernetes resource that automatically creates **Jobs** according to a defined schedule.

It works similarly to the Linux **cron** service.

Instead of manually running a task every day or every hour, Kubernetes executes it automatically.

---

# Why Do We Need CronJobs?

A **Job** runs only once.

Suppose you need to:

- Backup database every night
- Generate reports every morning
- Clean temporary files every hour
- Sync data every 5 minutes

Creating Jobs manually every time is not practical.

CronJobs automate these repetitive tasks.

---

# Deployment vs Job vs CronJob

| Deployment | Job | CronJob |
|------------|-----|----------|
| Long-running application | One-time task | Scheduled recurring task |
| Keeps Pods running | Runs once and exits | Creates Jobs on schedule |
| Example: Nginx | Database migration | Daily backup |

---

# CronJob Architecture

```text
                 CronJob
                     │
             Time Scheduler
                     │
          Scheduled Time Reached
                     │
                     ▼
               Creates Job
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
                     ▼
             Task Completed
```

> **Important:** A CronJob never creates Pods directly. It always creates a Job first, and the Job creates the Pod.

---

# CronJob Lifecycle

```text
Cron Schedule
    ↓
CronJob Triggered
    ↓
Job Created
    ↓
Pod Created
    ↓
Container Executes
    ↓
Job Completed
    ↓
Wait for Next Schedule
```

---

# Simple CronJob Example

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-cronjob
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: hello
            image: busybox:1.36
            command:
            - sh
            - -c
            - |
              echo "Hello from CronJob"
              date
```

Apply:

```bash
kubectl apply -f cronjob.yaml
```

---

# Verifying CronJob

View CronJobs

```bash
kubectl get cronjobs
```

View Jobs

```bash
kubectl get jobs
```

View Pods

```bash
kubectl get pods
```

View Logs

```bash
kubectl logs <pod-name>
```

---

# Understanding Cron Schedule

Cron expression contains **5 fields**.

```text
* * * * *
│ │ │ │ │
│ │ │ │ └── Day of Week (0-6)
│ │ │ └──── Month (1-12)
│ │ └────── Day of Month (1-31)
│ └──────── Hour (0-23)
└────────── Minute (0-59)
```

---

## Common Examples

Every minute

```text
* * * * *
```

Every 5 minutes

```text
*/5 * * * *
```

Every hour

```text
0 * * * *
```

Daily at 2 AM

```text
0 2 * * *
```

Every Sunday at midnight

```text
0 0 * * 0
```

Every Monday at 9:30 AM

```text
30 9 * * 1
```

---

# CronJob Creates Jobs

Suppose:

```yaml
schedule: "*/1 * * * *"
```

Execution:

```text
10:00 → Job-1

10:01 → Job-2

10:02 → Job-3

10:03 → Job-4
```

Every scheduled execution creates a **new Job**, and each Job creates its own Pod.

---

# Concurrency Policy

Sometimes a Job takes longer than the schedule interval.

Example:

- Schedule = Every minute
- Job duration = 2 minutes

What should Kubernetes do?

---

## Allow (Default)

```yaml
concurrencyPolicy: Allow
```

New Jobs start even if previous Jobs are still running.

```text
Job-1 Running

↓

Job-2 Starts

↓

Job-3 Starts
```

Multiple Jobs can run simultaneously.

---

## Forbid

```yaml
concurrencyPolicy: Forbid
```

If a previous Job is still running, Kubernetes skips the next schedule.

```text
Job-1 Running

↓

Next Schedule

↓

Skipped
```

Useful for:

- Database backups
- Data migration
- Report generation

---

## Replace

```yaml
concurrencyPolicy: Replace
```

If a previous Job is still running:

```text
Terminate Job-1
    ↓
Start Job-2
```

Useful when only the latest execution matters.

Example:
- Cache refresh
- Synchronization tasks

---

# Concurrency Comparison

| Policy | Previous Job Running | Result |
|---------|----------------------|--------|
| Allow | Yes | Start another Job |
| Forbid | Yes | Skip current schedule |
| Replace | Yes | Stop old Job and start new Job |

---

# Job History Management

CronJobs automatically remove old Jobs.

Two fields control this:

```yaml
successfulJobsHistoryLimit: 3

failedJobsHistoryLimit: 1
```

Default values:

- Successful Jobs = 3
- Failed Jobs = 1

Example:

```text
Job1

Job2

Job3

Job4
```

After Job4 completes:

```text
Delete Job1

Keep Job2

Keep Job3

Keep Job4
```

---

# startingDeadlineSeconds

Sometimes Kubernetes misses a scheduled execution.

Example:

- Control plane restart
- Scheduler unavailable
- Cluster maintenance

Use:

```yaml
startingDeadlineSeconds: 30
```

Meaning:

> If Kubernetes cannot start the Job within 30 seconds of its scheduled time, skip it.

Timeline:

```text
10:01
Schedule Missed
↓
Scheduler Returns
↓
20 Seconds Late
↓
Create Job
```

Another example:

```text
10:01
Schedule Missed
↓
Scheduler Returns
↓
45 Seconds Late
↓

Skip Job
```

---

# Suspend

Temporarily pause a CronJob.

```yaml
suspend: true
```

Result:

```text
CronJob Exists

↓

No New Jobs Created
```

Resume:

```yaml
suspend: false
```

Scheduling continues automatically.

---

## Important

Suspending a CronJob does **not** stop running Jobs.

Only future schedules are paused.

---

# Complete Production Example

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  startingDeadlineSeconds: 300
  suspend: false
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 600
      backoffLimit: 3
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: backup
            image: busybox:1.36
            command:
            - sh
            - -c
            - |
              echo "Starting backup..."
              sleep 10
              echo "Backup completed."
```

---

# Useful Commands

Create CronJob

```bash
kubectl apply -f cronjob.yaml
```

View CronJobs

```bash
kubectl get cronjobs
```

Describe CronJob

```bash
kubectl describe cronjob <cronjob-name>
```

View Jobs

```bash
kubectl get jobs
```

View Pods

```bash
kubectl get pods
```

View Logs

```bash
kubectl logs <pod-name>
```

Delete CronJob

```bash
kubectl delete cronjob <cronjob-name>
```

Pause CronJob

```bash
kubectl patch cronjob <cronjob-name> \
-p '{"spec":{"suspend":true}}'
```

Resume CronJob

```bash
kubectl patch cronjob <cronjob-name> \
-p '{"spec":{"suspend":false}}'
```

---

# Common Issues

## CronJob Not Running

Possible causes:

- Wrong schedule expression
- `suspend: true`
- Namespace mismatch

Check:

```bash
kubectl describe cronjob <cronjob-name>
```

---

## Too Many Jobs

Reduce:

```yaml
successfulJobsHistoryLimit

failedJobsHistoryLimit
```

---

## Multiple Jobs Running Together

Check:

```yaml
concurrencyPolicy
```

Use:

```yaml
Forbid
```

or

```yaml
Replace
```

---

## Missed Executions

Configure:

```yaml
startingDeadlineSeconds
```

---

# Real-World Use Cases

- Database backups
- Report generation
- Log cleanup
- Cache refresh
- ETL pipelines
- Data synchronization
- Certificate renewal
- Email notifications
- Scheduled maintenance

---

# Interview Questions

### Does a CronJob create Pods directly?

No.

CronJob creates a Job, and the Job creates the Pod.

---

### Difference between Job and CronJob?

**Job**

Runs once.

**CronJob**

Creates Jobs repeatedly according to a schedule.

---

### What is the default concurrencyPolicy?

```text
Allow
```

---

### What is the default history limit?

```text
successfulJobsHistoryLimit = 3

failedJobsHistoryLimit = 1
```

---

### What does suspend do?

Temporarily pauses future scheduled executions without deleting the CronJob.

---

### What does startingDeadlineSeconds do?

Defines how late Kubernetes can start a missed Job before skipping it.

---

# Best Practices & Key Learnings

- Use meaningful cron schedules and pin image versions instead of `latest`.
- Prefer `concurrencyPolicy: Forbid` for backup, migration, and other non-overlapping tasks.
- Keep `successfulJobsHistoryLimit` and `failedJobsHistoryLimit` low to avoid job clutter.
- Set `startingDeadlineSeconds` for time-sensitive schedules and missed windows.
- Use `ttlSecondsAfterFinished` or cleanup policies to remove finished Jobs.
- Suspend CronJobs during maintenance instead of deleting them.
- Define CPU/memory requests and limits for CronJob containers.
- CronJobs create Jobs, not Pods; each schedule creates a new Job.
- `suspend: true` pauses future executions only; running Jobs continue.
- CronJobs are ideal for backups, reports, cleanup, syncs, and scheduled maintenance.