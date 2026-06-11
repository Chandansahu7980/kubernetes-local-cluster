# 🗄️ Kubernetes StatefulSet with MySQL (PV, PVC, Headless Service)

## 📌 Overview

This document demonstrates how to deploy a **stateful MySQL database** in Kubernetes using:

* StatefulSet
* PersistentVolume (PV)
* PersistentVolumeClaim (PVC)
* Headless Service
* Secret (for password management)

---

## 🧠 Key Concepts

### 🔹 StatefulSet

* Provides **stable pod identity**
* Example pod names:

  ```
  mysql-0
  mysql-1
  ```

---

### 🔹 PersistentVolume (PV)

* Represents actual storage in the cluster
* Manually created in local setup (hostPath)

---

### 🔹 PersistentVolumeClaim (PVC)

* Requests storage from PV
* Automatically created by StatefulSet

---

### 🔹 Headless Service

```yaml
clusterIP: None
```

* No load balancing
* Provides **direct DNS to pods**

---

## 📁 Manifest Files

```
manifests/
├── mysql-secret.yaml
├── mysql-statefulset-pv.yaml
├── mysql-headless-service.yaml
└── mysql-statefulset.yaml
```

---

## 🔐 1. Create Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  MYSQL_ROOT_PASSWORD: bXlwYXNzd29yZA==  # base64 encoded
```

Apply:

```bash
kubectl apply -f mysql-secret.yaml
```

---

## 💾 2. Create PersistentVolume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-statefulset-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data/mysql-pv
```

Apply:

```bash
kubectl apply -f mysql-statefulset-pv.yaml
```

---

### ⚠️ Important

Create directory on node:

```bash
sudo mkdir -p /mnt/data/mysql-pv
sudo chmod -R 777 /mnt/data
```

---

## 🌐 3. Create Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
    - port: 3306
```

Apply:

```bash
kubectl apply -f mysql-headless-service.yaml
```

---

## 🚀 4. Deploy StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql-headless
  replicas: 1

  selector:
    matchLabels:
      app: mysql

  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306

        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_ROOT_PASSWORD

        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql

  volumeClaimTemplates:
  - metadata:
      name: mysql-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

Apply:

```bash
kubectl apply -f mysql-statefulset.yaml
```

---

## 🔍 Verification Steps

---

### 1️⃣ Check Pods

```bash
kubectl get pods -o wide
```

Expected:

```
mysql-0   Running
```

---

### 2️⃣ Check PVC

```bash
kubectl get pvc
```

Expected:

```
mysql-storage-mysql-0   Bound
```

---

### 3️⃣ Check PV

```bash
kubectl get pv
```

Expected:

```
mysql-pv   Bound
```

---

### 4️⃣ Check Service

```bash
kubectl get svc
```

Expected:

```
mysql-headless   ClusterIP: None
```

---

## 🔗 Access MySQL

---

### 🔹 Option 1: Inside Pod

```bash
kubectl exec -it mysql-0 -- /bin/bash
mysql -u root -p
```

---

### 🔹 Option 2: From Another Pod (Recommended)

```bash
kubectl run mysql-client --rm -it --image=mysql:8.0 -- bash
```

Then:

```bash
mysql -h mysql-0.mysql-headless -u root -p
```

---

## 🧪 Test Stateful Behavior

---

### 1️⃣ Insert Data

```sql
CREATE DATABASE testdb;
USE testdb;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50)
);

INSERT INTO users (name) VALUES ('StatefulTest');
```

---

### 2️⃣ Delete Pod

```bash
kubectl delete pod mysql-0
```

---

### 3️⃣ Verify Data Persistence

Reconnect and run:

```sql
USE testdb;
SELECT * FROM users;
```

✅ Data should persist

---

## 🌐 DNS Testing (Best Practice)

---

### ❌ Avoid installing tools inside app containers

---

### ✅ Use Debug Pod

```bash
kubectl run dns-test --rm -it --image=busybox:1.28 -- sh
```

Test:

```bash
nslookup mysql-headless
nslookup mysql-0.mysql-headless
```

---

## ⚠️ Common Issues & Fixes

---

### ❌ PVC Pending

Error:

```
no persistent volumes available
```

✔ Fix:

* Create PV manually
* Ensure size & accessModes match

---

### ❌ PV Immutable Error

Error:

```
spec.persistentvolumesource is immutable
```

✔ Fix:

```bash
kubectl delete pv mysql-statefulset-pv
kubectl apply -f mysql-statefulset-pv.yaml
```

---

### ❌ Pod Not Starting

Check:

```bash
kubectl describe pod mysql-0
kubectl describe pvc
```

---

## 🔥 Key Learnings

* StatefulSet provides **stable identity**
* PVC is created **per pod**
* Headless service enables **pod-level DNS**
* PV must exist (or use StorageClass)
* Storage is **persistent across pod restarts**

---

## 🚀 Next Steps

* Scale StatefulSet
* Add replication (MySQL cluster)
* Implement Ingress
* Explore StorageClass (dynamic provisioning)

---