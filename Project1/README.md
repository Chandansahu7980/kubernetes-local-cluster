# PHP CRUD Application on Kubernetes using StatefulSet, NFS StorageClass and Dynamic Provisioning

## Project Overview

This project demonstrates deployment of a PHP CRUD application and MySQL database on Kubernetes using production-style Kubernetes resources.

The objective is to understand how stateless and stateful applications are deployed and managed in Kubernetes.

This project covers:

* Docker Image Creation
* Kubernetes Deployment
* ConfigMaps
* Secrets
* Services
* StatefulSets
* Headless Services
* StorageClass
* Dynamic Provisioning
* NFS Persistent Storage
* MySQL Stateful Applications
* PHP Stateless Applications

---

# Architecture

```text
Browser
   |
   |
NodePort Service
   |
   |
PHP Deployment
   |
   |
ConfigMap + Secret
   |
   |
MySQL StatefulSet
   |
Headless Service
   |
PVC
   |
StorageClass (NFS)
   |
NFS Provisioner
   |
NFS Server
```

---

# Project Structure

```text
Project2/
│
├── app/
│   ├── create.php
│   ├── db.php
│   ├── delete.php
│   ├── edit.php
│   ├── index.php
│   └── Dockerfile
│
├── manifests/
│   ├── namespace.yaml
│   │
│   ├── mysql/
│   │   ├── mysql-secret.yaml
│   │   ├── mysql-headless-svc.yaml
│   │   └── mysql-statefulset.yaml
│   │
│   └── php/
│       ├── php-configmap.yaml
│       ├── php-deployment.yaml
│       └── php-service.yaml
│
└── README.md
```

---

# Prerequisites

Before starting:

* Ubuntu Linux
* Kubernetes Cluster
* kubeadm
* containerd
* NFS Server
* NFS Subdir External Provisioner
* Dynamic StorageClass
* kubectl

Verify:

```bash
kubectl get nodes
kubectl get storageclass
```

Expected:

```bash
NAME                   PROVISIONER
nfs-client (default)   cluster.local/nfs-storage-nfs-subdir-external-provisioner
```

---

# Step 1 - Build Docker Image

Move to application directory:

```bash
cd app
```

Build image:

```bash
docker build -t php-crud-app:v1 .
```

Verify image:

```bash
docker images
```

Expected:

```bash
php-crud-app   v1
```

---

# Step 2 - Export Docker Image

Export image as tar file:

```bash
docker save php-crud-app:v1 -o php-crud-app.tar
```

Verify:

```bash
ls -lh php-crud-app.tar
```

---

# Step 3 - Copy Image to Shared NFS Location

Example:

```bash
cp php-crud-app.tar /srv/nfs/shared/
```

Verify:

```bash
ls /srv/nfs/shared/
```

---

# Step 4 - Import Image into Containerd

Perform on all Kubernetes nodes.

Master:

```bash
sudo ctr -n k8s.io images import /srv/nfs/shared/php-crud-app.tar
```

Worker1:

```bash
sudo ctr -n k8s.io images import /srv/nfs/shared/php-crud-app.tar
```

Worker2:

```bash
sudo ctr -n k8s.io images import /srv/nfs/shared/php-crud-app.tar
```

Verify:

```bash
sudo ctr -n k8s.io images ls | grep php
```

Expected:

```bash
php-crud-app:v1
```

---

# Step 5 - Create Namespace

```bash
kubectl apply -f manifests/namespace.yaml
```

Verify:

```bash
kubectl get ns
```

---

# Step 6 - Deploy MySQL Secret

```bash
kubectl apply -f manifests/mysql/mysql-secret.yaml
```

Verify:

```bash
kubectl get secret -n pro2
```

---

# Step 7 - Deploy Headless Service

```bash
kubectl apply -f manifests/mysql/mysql-headless-svc.yaml
```

Verify:

```bash
kubectl get svc -n pro2
```

Expected:

```bash
mysql-headless
```

---

# Step 8 - Deploy MySQL StatefulSet

```bash
kubectl apply -f manifests/mysql/mysql-statefulset.yaml
```

Verify:

```bash
kubectl get pods -n pro2
kubectl get pvc -n pro2
```

Expected:

```bash
mysql-sts-0
```

---

# Step 9 - Verify Dynamic Provisioning

Check PVC:

```bash
kubectl get pvc -n pro2
```

Check PV:

```bash
kubectl get pv
```

Observe:

```text
PVC --> PV --> NFS Directory
```

created automatically.

---

# Step 10 - Create Database

Login:

```bash
kubectl exec -it mysql-sts-0 -n pro2 -- mysql -uroot -p
```

Create database:

```sql
CREATE DATABASE cruddb;

USE cruddb;

CREATE TABLE users(
id INT PRIMARY KEY AUTO_INCREMENT,
name VARCHAR(100),
email VARCHAR(100)
);
```

Verify:

```sql
SHOW TABLES;
```

---

# Step 11 - Deploy ConfigMap

```bash
kubectl apply -f manifests/php/php-configmap.yaml
```

Verify:

```bash
kubectl describe cm php-configmap -n pro2
```

---

# Step 12 - Deploy PHP Application

```bash
kubectl apply -f manifests/php/php-deployment.yaml
```

Verify:

```bash
kubectl get pods -n pro2
```

Expected:

```bash
php-deployment-xxxxx
```

---

# Step 13 - Deploy NodePort Service

```bash
kubectl apply -f manifests/php/php-service.yaml
```

Verify:

```bash
kubectl get svc -n pro2
```

Expected:

```bash
php-service
```

---

# Step 14 - Access Application

Find node IP:

```bash
kubectl get nodes -o wide
```

Access:

```text
http://<Node-IP>:30080
```

Example:

```text
http://192.168.56.10:30080
```

---

# StatefulSet DNS

StatefulSet Pods receive stable DNS identities.

Example:

```text
mysql-sts-0.mysql-headless
mysql-sts-1.mysql-headless
mysql-sts-2.mysql-headless
```

Verify:

```bash
kubectl exec -it <php-pod> -n pro2 -- getent hosts mysql-sts-0.mysql-headless
```

---

# Testing Persistence

Insert records.

Delete pod:

```bash
kubectl delete pod mysql-sts-0 -n pro2
```

Wait for recreation.

Verify data still exists.

This confirms persistent storage functionality.

---

# Concepts Learned

## Stateless Applications

PHP Deployment

Characteristics:

* Multiple replicas
* Easily replaceable
* No local data dependency

## Stateful Applications

MySQL StatefulSet

Characteristics:

* Stable hostname
* Stable storage
* Ordered deployment
* Dedicated PVC per Pod

## StorageClass

Provides dynamic volume provisioning.

## PVC

Storage request by application.

## PV

Actual storage resource created dynamically.

## Headless Service

Provides stable DNS entries for StatefulSet Pods.

---

# Troubleshooting

## PHP Cannot Connect to MySQL

Incorrect:

```text
mysql-sts-0
```

Correct:

```text
mysql-sts-0.mysql-headless
```

---

## PVC Pending

Check StorageClass:

```bash
kubectl get sc
```

Verify:

```yaml
storageClassName: nfs-client
```

---

## Pod Scheduling Failure

Check:

```bash
kubectl describe pvc
```

---

## Image Pull Error

Import image on all nodes:

```bash
sudo ctr -n k8s.io images import php-crud-app.tar
```

Use:

```yaml
imagePullPolicy: Never
```

---

# Future Enhancements

* Ingress Controller
* HTTPS/TLS
* Helm Chart
* MySQL Replication
* Horizontal Pod Autoscaler
* Monitoring with Prometheus
* Grafana Dashboards
* CI/CD Pipeline
* ArgoCD GitOps

```
```