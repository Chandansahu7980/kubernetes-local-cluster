# Hands-On Project: Deploying a Multi-Tier App with Helm

A quick, practical lab to build, configure, deploy, and update a custom Helm chart on a local Kubernetes cluster. This project demonstrates how Helm manages variables, templates, and releases.

---

## 1. Project Architecture

This project deploys a standard two-tier web application:

* **Frontend:** A custom Nginx web server.
* **Backend/Database:** A PostgreSQL instance deployed as a dependency chart.

---

## 2. Lab Prerequisites

Before starting, ensure you have:

* A local running Kubernetes cluster (for example, Minikube, Kind, or a Vagrant setup).
* `kubectl` installed and configured for your cluster.
* `helm` installed.
* A working `StorageClass` in the cluster so the database can request persistent storage.

---

## 3. Step-by-Step Implementation Guide

### Step 1: Initialize Your First Helm Chart

Run these commands in your terminal to scaffold a standard Helm chart:

```bash
helm create webapp-chart
cd webapp-chart
```

### Step 2: Clean Up the Default Templates

Remove the default templates so you can build a minimal custom frontend chart:

```bash
rm -rf templates/*
```

### Step 3: Add the Database Dependency

Open `Chart.yaml` and add the PostgreSQL dependency block:

```yaml
apiVersion: v2
name: webapp-chart
description: A starter hands-on project to master Helm
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  - name: postgresql
    version: "15.5.3"
    repository: "https://charts.bitnami.com/bitnami"
```

Download the dependency bundle:

```bash
helm dependency update
```

### Step 4: Define Your Global Variables (`values.yaml`)

Replace the contents of `values.yaml` with these values:

```yaml
# Frontend web settings
replicaCount: 2
image:
  repository: nginx
  tag: stable

service:
  type: NodePort
  port: 80

# Sub-chart database overrides
postgresql:
  auth:
    database: my_app_db
    username: db_user
    password: Password123
  architecture: standalone
  startupProbe:
    enabled: true
    initialDelaySeconds: 10
    periodSeconds: 15
    failureThreshold: 20
```

### Step 5: Write the Frontend Blueprints

Create the frontend templates in the `templates/` directory.

#### Create `templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-frontend
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}-web
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-web
    spec:
      containers:
        - name: web-server
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 80
```

#### Create `templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-frontend-svc
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
      nodePort: 32080
  selector:
    app: {{ .Release.Name }}-web
```

Return to the chart root:

```bash
cd ..
```

---

## 4. Deploying and Testing the Release

### 4.1 Pre-deployment Validation

Check the chart syntax and structure:

```bash
helm lint .
```

Render the templates locally without installing:

```bash
helm install quickstart-release . --dry-run
```

### 4.2 Execute the Installation

Deploy the application stack:

```bash
helm upgrade --install quickstart-release .
```

### 4.3 Track Status

Verify the deployed pods and service:

```bash
kubectl get pods -w
kubectl get service
```

You should see 2 Nginx frontend pods and 1 PostgreSQL backend pod running.

---

## 5. Testing the Power of Helm

### Scenario A: Scaling Up

To scale the frontend, update `values.yaml`:

```yaml
replicaCount: 4
```

Apply the change:

```bash
helm upgrade quickstart-release .
```

Then verify the new pod count:

```bash
kubectl get pods
```

### Scenario B: Rollback Safety Net

View the release history:

```bash
helm history quickstart-release
```

Rollback to a previous revision:

```bash
helm rollback quickstart-release 1
```

Helm will restore the cluster to the selected revision automatically.