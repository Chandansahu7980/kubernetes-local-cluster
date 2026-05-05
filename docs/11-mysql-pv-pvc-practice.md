# 11 - MySQL with Persistent Volumes (Real-World Practice)

This document demonstrates running a **stateful application (MySQL)** using:

* Persistent Volumes (PV)
* Persistent Volume Claims (PVC)
* Secrets (for credentials)
* Deployment & Service

---

## 📌 Objective

* Understand PV ↔ PVC relationship
* Deploy MySQL with persistent storage
* Store real database data
* Verify data persistence after pod restart

---

# 🧠 Architecture Overview

```text
MySQL Pod → PVC → PV → Node Disk
```

---

# 📁 Files Used

```text
manifests/
├── 08-mysql-pv.yaml
├── 08-mysql-pvc.yaml
├── 08-mysql-secret.yaml
├── 08-mysql-deployment.yaml
├── 08-mysql-service.yaml
```

---

# 🧪 Step 1: Create Persistent Volume

```bash
kubectl apply -f manifests/08-mysql-pv.yaml
```

---

## 📌 Verify

```bash
kubectl get pv
```

---

# 🧪 Step 2: Create PVC

```bash
kubectl apply -f manifests/08-mysql-pvc.yaml
```

---

## 📌 Verify Binding

```bash
kubectl get pvc
```

Expected:

```text
STATUS = Bound
```

---

# 🧪 Step 3: Create Secret

```bash
kubectl apply -f manifests/08-mysql-secret.yaml
```

---

## 📌 Verify

```bash
kubectl get secret
```

---

# 🧪 Step 4: Deploy MySQL

```bash
kubectl apply -f manifests/08-mysql-deployment.yaml
```

---

## 📌 Verify Pod

```bash
kubectl get pods
```

---

# 🧪 Step 5: Create Service

```bash
kubectl apply -f manifests/08-mysql-service.yaml
```

---

## 📌 Verify

```bash
kubectl get svc
```

---

# 🧪 Step 6: Connect to MySQL Pod

```bash
kubectl exec -it <mysql-pod-name> -- /bin/bash
```

---

## 🧪 Login to MySQL

```bash
mysql -u root -p
```

Enter password (from Secret)

---

# 🧪 Step 7: Create Database & Table

```sql
CREATE DATABASE testdb;
USE testdb;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50)
);

INSERT INTO users (name) VALUES ('Chandan');

SELECT * FROM users;
```

---

## 📌 Expected Output

```text
+----+---------+
| id | name    |
+----+---------+
|  1 | Chandan |
+----+---------+
```

---

# 🧪 Step 8: Delete Pod

```bash
kubectl delete pod <mysql-pod-name>
```

---

# 🧪 Step 9: Verify Persistence

Reconnect:

```bash
kubectl exec -it <new-mysql-pod> -- /bin/bash
mysql -u root -p
```

```sql
USE testdb;
SELECT * FROM users;
```

---

## ✅ Expected Result

```text
Data still exists ✔
```

---

# 🧠 Key Learning

* Data is stored in PV, not in pod
* PVC acts as a bridge between pod and storage
* Pod recreation does NOT delete data

---

# ⚠️ Important Limitation (hostPath)

* Storage is tied to node
* If pod moves to another node → data may be lost

---

# ⚠️ Common Issues

---

## ❌ PVC Pending

```text
STATUS = Pending
```

### Cause:

* No matching PV

---

## ❌ MySQL Pod Not Starting

```bash
kubectl describe pod <pod>
```

### Common Reasons:

* PVC not bound
* Secret missing
* Volume mount issue

---

## ❌ Permission Issues

### Fix:

```bash
sudo chmod -R 777 /mnt/data
```

---

## ❌ Cannot Connect to MySQL

Check:

```bash
kubectl logs <pod>
```

---

# 🧠 Real-World Insight

This setup simulates:

* Database persistence
* Stateful workloads
* Production-like architecture

---

# 🎯 Outcome

* MySQL deployed successfully
* Data persisted across pod restart
* PV and PVC relationship understood

---

# 📚 Key Concepts

| Component | Role            |
| --------- | --------------- |
| PV        | Actual storage  |
| PVC       | Storage request |
| Pod       | Uses storage    |
| Secret    | Stores password |

---

# 🔜 Next Step

* Ingress Controller
* Domain-based access (instead of NodePort)