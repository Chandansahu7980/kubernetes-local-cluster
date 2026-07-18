# Why Was Node Affinity Introduced?

Before Kubernetes v1.6, the primary way to control Pod placement was **NodeSelector**.

Example:

```yaml
nodeSelector:
  disktype: ssd
```

Although NodeSelector is simple and easy to use, it has several limitations.

It only supports **exact label matching** and cannot express more advanced scheduling requirements.

Imagine a cluster with three worker nodes.

| Node | Labels |
|-------|-------------------------------|
| worker1 | disktype=ssd, region=east |
| worker2 | disktype=ssd, region=west |
| worker3 | disktype=hdd, region=east |

Now suppose your application requires:

- Run only on SSD nodes
- Prefer the East region
- Avoid HDD nodes
- Allow multiple matching values
- Support complex scheduling rules

NodeSelector cannot express these requirements.

To overcome these limitations, Kubernetes introduced **Node Affinity**, which provides flexible and intelligent scheduling based on Node labels.

---

# What is Node Affinity?

Node Affinity is an **advanced scheduling feature** that allows a Pod to specify **rules about which Nodes it can or should run on**.

Unlike NodeSelector, Node Affinity supports:

- Multiple label matching
- Flexible operators
- Hard scheduling rules
- Soft scheduling preferences
- Complex scheduling logic

Node Affinity evaluates **Node Labels** during scheduling and determines whether a Pod should be placed on a particular Node.

Think of Node Affinity as:

> "This Pod has preferences and requirements about where it wants to run."

---

# NodeSelector vs Node Affinity

Both NodeSelector and Node Affinity are used to schedule Pods onto specific Nodes, but Node Affinity is much more powerful.

| Feature | NodeSelector | Node Affinity |
|----------|--------------|---------------|
| Uses Node Labels | ✅ | ✅ |
| Exact Match | ✅ | ✅ |
| Multiple Match Expressions | ❌ | ✅ |
| AND Conditions | ❌ | ✅ |
| OR Conditions | ✅ (multiple nodeSelectorTerms) |
| Advanced Operators | ❌ | ✅ |
| Preferred Scheduling | ❌ | ✅ |
| Required Scheduling | ❌ | ✅ |
| Production Flexibility | Basic | Advanced |

Think of them like this:

### NodeSelector

```
Pod

↓

"I want exactly this Node label."
```

### Node Affinity

```
Pod

↓

"I must run here..."

AND

"I prefer this location..."

AND

"I want to avoid these Nodes..."
```

NodeSelector is ideal for simple scheduling.

Node Affinity is recommended for production workloads.

---

# Types of Node Affinity

Kubernetes provides two types of Node Affinity.

## 1. Required Node Affinity

```text
requiredDuringSchedulingIgnoredDuringExecution
```

Also called **Hard Scheduling**.

The scheduling rule **must** be satisfied.

If no Node matches the rule:

```
Pod

↓

Pending
```

Examples:

- MySQL must run on SSD nodes.
- GPU workloads must run on GPU-enabled nodes.
- Monitoring workloads must run only on monitoring nodes.

---

## 2. Preferred Node Affinity

```text
preferredDuringSchedulingIgnoredDuringExecution
```

Also called **Soft Scheduling**.

The scheduler tries to satisfy the rule.

If no matching Node is available, Kubernetes schedules the Pod on another suitable Node.

Examples:

- Prefer SSD nodes.
- Prefer East region.
- Prefer nodes with better hardware.
- Prefer Nodes in the same availability zone.

---

# Node Affinity Workflow

```
Deployment
      │
      ▼
Scheduler
      │
      ▼
Read Node Affinity Rules
      │
      ▼
Check Node Labels
      │
 ┌────┴────┐
 │         │
Required?  Preferred?
 │         │
 │         │
Must Match Try Best
 │         │
 ▼         ▼
Schedule   Score Nodes
```

---

This topic is divided into two chapters.

✔ Required Node Affinity

- Hard Scheduling
- Match Expressions
- Operators
- AND Conditions
- Troubleshooting
- Hands-on Labs

✔ Preferred Node Affinity

- Soft Scheduling
- Weight
- Node Scoring
- Multiple Preferences
- Required + Preferred
- Production Examples
- Scheduler Decision Process