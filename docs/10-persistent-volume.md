# 10 - Persistent Volumes (Storage in Kubernetes)

This document explains how Kubernetes handles storage using Persistent Volumes (PV) and Persistent Volume Claims (PVC), with a practical example of storing **nginx access logs** for better real-world understanding.

---

## 📌 Objective

* Understand PV & PVC
* Create persistent storage
* Attach storage to pods
* Store nginx access logs persistently
* Verify data persistence after pod restart

---

# 🧠 Why Storage is Needed?

By default:

* Pods are **ephemeral**
* Data is lost when pod is deleted

---

## 🧪 Example Problem

```text
Delete pod → Logs lost ❌
```

---

## ✅ Solution

Use:

* PersistentVolume (PV)
* PersistentVolumeClaim (PVC)

---

# 🧠 Core Concepts

---

## 📦 Persistent Volume (PV)

* Actual storage (disk)
* Created by admin or manually
* Example: local disk, cloud disk

---

## 📦 Persistent Volume Claim (PVC)

* Request for storage
* Created by developer
* Pod uses PVC, not PV directly

---

## 🔗 Flow

```text
Pod → PVC → PV → Disk
```

---

# 🧪 Step 1: Create Persistent Volume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data
```

---

## 🧠 Explanation

* `1Gi` → storage size
* `hostPath` → uses node's local disk
* Good for learning (not production)

---

## 🧪 Apply

```bash
kubectl apply -f pv.yaml
```

---

# 🧪 Step 2: Create PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

---

## 🧪 Apply

```bash
kubectl apply -f pvc.yaml
```

---

## 🧪 Verify Binding

```bash
kubectl get pv
kubectl get pvc
```

---

### 📌 Expected

```text
STATUS = Bound
```

---

# 🧪 Step 3: Use PVC for Nginx Access Logs

Instead of storing static files, we will store **nginx access logs**, which is a real-world use case.

---

## 🧠 Default Nginx Log Path

```text
/var/log/nginx/access.log
```

---

## 🧱 Update Deployment

Modify your deployment to mount storage at nginx log directory:

```yaml
volumeMounts:
- mountPath: "/var/log/nginx"
  name: log-storage

volumes:
- name: log-storage
  persistentVolumeClaim:
    claimName: local-pvc
```

---

## 🧪 Apply

```bash
kubectl apply -f nginx-deployment.yaml
```

---

# 🧪 Step 4: Generate Logs

Access your service multiple times:

```bash
curl http://<NodeIP>:30007
```

Run it multiple times to generate logs.

---

# 🧪 Step 5: Verify Logs Inside Pod

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

Check logs:

```bash
cat /var/log/nginx/access.log
```

---

### 📌 Expected

```text
GET / HTTP/1.1 ...
GET / HTTP/1.1 ...
```

---

# 🧪 Step 6: Delete Pod

```bash
kubectl delete pod <pod-name>
```

---

# 🧪 Step 7: Verify Persistence

After new pod is created:

```bash
kubectl exec -it <new-pod> -- /bin/sh
cat /var/log/nginx/access.log
```

---

### 📌 Expected

```text
Previous logs still exist ✅
```

---

# 🧠 Learning

* Logs persist even after pod restart
* Storage is independent of pod lifecycle
* Real-world use case: logging, monitoring

---

# ⚠️ Common Issues

---

## ❌ PVC Not Bound

```text
STATUS = Pending
```

### Cause:

* No matching PV

---

### Fix:

```bash
kubectl describe pvc local-pvc
```

---

## ❌ Permission Issues

* Nginx cannot write logs

### Fix:

```bash
chmod -R 777 /mnt/data
```

---

## ❌ Logs Not Updating

### Cause:

* Wrong mount path

### Fix:

Ensure correct path:

```text
/var/log/nginx
```

---

## ❌ Data Not Persisting

### Cause:

* volumeMount not configured properly

---

# 🧠 Real-World Note

`hostPath`:

* Only for learning
* Not used in production

Production uses:

* AWS EBS
* Azure Disk
* NFS
* CSI drivers

---

# 🎯 Outcome

* Persistent storage configured
* Nginx logs stored persistently
* Data survives pod deletion
* PVC successfully bound to PV

---

# 📚 Key Learnings

* PV = actual storage
* PVC = request for storage
* Pod uses PVC
* Logs/data persist across restarts

---

# 🔜 Next Step

* Ingress (access apps via domain)
* Better than NodePort