# PHP CRUD Application Deployment on Kubernetes

> containerd + NFS + MySQL + PHP

## Cluster Setup

- **Master Node:** 1
- **Worker Nodes:** 2
- **Container Runtime:** containerd
- **Shared Storage:** NFS

## Project Structure

```text
php-k8s-crud/
├── app/
│   ├── index.php
│   ├── create.php
│   ├── edit.php
│   ├── delete.php
│   ├── db.php
│   └── Dockerfile
└── k8s/
    ├── namespace.yaml
    ├── mysql-secret.yaml
    ├── mysql-configmap.yaml
    ├── nfs-pv.yaml
    ├── mysql-pvc.yaml
    ├── mysql-deployment.yaml
    ├── mysql-service.yaml
    ├── php-configmap.yaml
    ├── php-deployment.yaml
    └── php-service.yaml
```

## Step 1 - Install Buildah

On the master node:

```bash
sudo apt update
sudo apt install -y buildah
```

Verify installation:

```bash
buildah version
```

## Step 2 - Build PHP Image

From the app directory:

```bash
cd ~/php-k8s-crud/app
buildah bud -t php-crud-app:v1 .
```

Verify the built image:

```bash
buildah images
```

## Step 3 - Export Image to NFS Shared Folder

Example shared folder:

```text
/mnt/k8s-share
```

Export the image:

```bash
buildah push php-crud-app:v1 \
  docker-archive:/mnt/k8s-share/php-crud-app.tar
```

## Step 4 - Import Image into containerd

On the master node and all workers:

```bash
sudo ctr -n k8s.io images import /mnt/k8s-share/php-crud-app.tar
```

Verify the imported image on each node:

```bash
sudo ctr -n k8s.io images ls | grep php
```

## Step 5 - Prepare NFS Storage

On the master node:

```bash
sudo mkdir -p /mnt/k8s-share/mysql-data
sudo chmod -R 777 /mnt/k8s-share/mysql-data
```

## Step 6 - Configure NFS Exports

Edit `/etc/exports`:

```bash
sudo nano /etc/exports
```

Add the following export:

```text
/mnt/k8s-share *(rw,sync,no_subtree_check,no_root_squash)
```

Reload exports:

```bash
sudo exportfs -ra
```

Verify exports:

```bash
showmount -e
```

## Step 7 - Deploy Kubernetes Resources

From the Kubernetes manifests directory:

```bash
cd ~/php-k8s-crud/k8s
```

### Apply Namespace

```bash
kubectl apply -f namespace.yaml
```

### Apply Persistent Volume

```bash
kubectl apply -f nfs-pv.yaml
kubectl get pv
```

### Apply Persistent Volume Claim

```bash
kubectl apply -f mysql-pvc.yaml
kubectl get pvc -n php-app
```

Expected status:

- `STATUS = Bound`

### Apply ConfigMaps and Secrets

```bash
kubectl apply -f mysql-configmap.yaml
kubectl apply -f mysql-secret.yaml
kubectl apply -f php-configmap.yaml
```

## Step 8 - Deploy MySQL

```bash
kubectl apply -f mysql-deployment.yaml
kubectl apply -f mysql-service.yaml
kubectl get pods -n php-app
```

Wait until the MySQL pod status is:

- `STATUS = Running`

## Step 9 - Check MySQL Logs

```bash
kubectl logs deployment/mysql -n php-app
```

Expected output includes:

- `MySQL init process done. Ready for start up.`

## Step 10 - Login to MySQL

Enter the MySQL pod shell:

```bash
kubectl exec -it deployment/mysql -n php-app -- bash
```

Then log in to MySQL:

```bash
mysql -u root -p
```

Password:

```text
root123
```

## Step 11 - Create Database Table

Inside the MySQL shell:

```sql
USE project1db;
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100)
);
```

Verify:

SHOW TABLES;

Exit:

exit;

====================================================
STEP 12 - DEPLOY PHP APPLICATION
====================================================

kubectl apply -f php-deployment.yaml

kubectl apply -f php-service.yaml

====================================================
STEP 13 - VERIFY PODS
====================================================

kubectl get pods -n php-app -o wide

Expected:

php-app-xxxxx Running
mysql-xxxxx Running

====================================================
STEP 14 - ACCESS APPLICATION
====================================================

Get node IP:

kubectl get nodes -o wide

Open browser:

http://<NODE-IP>:30080

Example:

http://192.168.1.20:30080

====================================================
STEP 15 - VERIFY CRUD OPERATIONS
====================================================

Test:

1. Add User
2. Edit User
3. Delete User

====================================================
STEP 16 - VERIFY PERSISTENT STORAGE
====================================================

Delete mysql pod:

kubectl delete pod -l app=mysql -n php-app

Wait for pod recreation.

Verify application data still exists.

====================================================
STEP 17 - USEFUL KUBERNETES COMMANDS
====================================================

Get Pods:

kubectl get pods -n php-app

Watch Pods:

kubectl get pods -n php-app -w

Pod Logs:

kubectl logs <pod-name> -n php-app

Describe Pod:

kubectl describe pod <pod-name> -n php-app

Enter Pod:

kubectl exec -it <pod-name> -n php-app -- bash

Delete Pod:

kubectl delete pod <pod-name> -n php-app

Scale Deployment:

kubectl scale deployment php-app \
--replicas=5 \
-n php-app

====================================================
STEP 18 - ROLLING UPDATE
====================================================

Build new image:

buildah bud -t php-crud-app:v2 .

Export image:

buildah push php-crud-app:v2 \
docker-archive:/mnt/k8s-share/php-crud-app-v2.tar

Import image on all nodes:

sudo ctr -n k8s.io images import \
/mnt/k8s-share/php-crud-app-v2.tar

Update deployment:

kubectl set image deployment/php-app \
php-app=php-crud-app:v2 \
-n php-app

Watch rollout:

kubectl rollout status deployment/php-app -n php-app

Rollback:

kubectl rollout undo deployment/php-app -n php-app

====================================================
TROUBLESHOOTING
====================================================

----------------------------------------------------
IMAGEPULLBACKOFF
----------------------------------------------------

Verify image exists:

sudo ctr -n k8s.io images ls

Ensure deployment contains:

imagePullPolicy: Never

----------------------------------------------------
MYSQL CRASHLOOPBACKOFF
----------------------------------------------------

Check logs:

kubectl logs deployment/mysql -n php-app

Fix permissions:

sudo chmod -R 777 /mnt/k8s-share/mysql-data

----------------------------------------------------
PVC PENDING
----------------------------------------------------

Check PV:

kubectl get pv

Check PVC:

kubectl get pvc -n php-app

----------------------------------------------------
PHP CANNOT CONNECT TO MYSQL
----------------------------------------------------

Verify environment variables:

kubectl exec -it deployment/php-app \
-n php-app -- env | grep MYSQL

Verify service:

kubectl get svc -n php-app

====================================================
KUBERNETES CONCEPTS PRACTICED
====================================================

1. Namespace
2. Deployment
3. ReplicaSet
4. Pod
5. Service
6. NodePort
7. ConfigMap
8. Secret
9. PersistentVolume
10. PersistentVolumeClaim
11. NFS Storage
12. containerd Runtime

====================================================
NEXT LEARNING TOPICS
====================================================

1. StatefulSet
2. Helm
3. Ingress Controller
4. MetalLB
5. HPA
6. Prometheus
7. Grafana
8. ArgoCD
9. RBAC
10. NetworkPolicy

====================================================
END
====================================================