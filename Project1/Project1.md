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
buildah push php-crud-app:v1 docker-archive:/svr/nfs/shared/php-crud-app.tar
```

## Step 4 - Import Image into containerd

On the master node and all workers:

```bash
sudo ctr -n k8s.io images import /svr/nfs/shared/php-crud-app.tar
```

Verify the imported image on each node:

```bash
sudo ctr -n k8s.io images ls | grep php
```

## Step 5 - Prepare NFS Storage

On the master node:

```bash
sudo mkdir -p /srv/nfs/shared/mysql-data
sudo chmod -R 777 /srv/nfs/shared/mysql-data
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
SHOW TABLES;
```

Exit the MySQL shell:

```bash
exit
```

## Step 12 - Deploy PHP Application

```bash
kubectl apply -f php-deployment.yaml
kubectl apply -f php-service.yaml
```

## Step 13 - Verify Pods

```bash
kubectl get pods -n php-app -o wide
```

Expected pods:

- `php-app-xxxxx` Running
- `mysql-xxxxx` Running

## Step 14 - Access Application

Get the node IP:

```bash
kubectl get nodes -o wide
```

Open the application in your browser:

```text
http://<NODE-IP>:30080
```

Example:

```text
http://192.168.1.20:30080
```

## Step 15 - Verify CRUD Operations

Test the application by performing:

1. Add User
2. Edit User
3. Delete User

## Step 16 - Verify Persistent Storage

Delete the MySQL pod and confirm data persistence:

```bash
kubectl delete pod -l app=mysql -n php-app
```

Wait for the MySQL pod to be recreated and verify data still exists.

Verify application data still exists.

## Step 17 - Useful Kubernetes Commands

### Get Pods

```bash
kubectl get pods -n php-app
```

### Watch Pods

```bash
kubectl get pods -n php-app -w
```

### View Pod Logs

```bash
kubectl logs <pod-name> -n php-app
```

### Describe a Pod

```bash
kubectl describe pod <pod-name> -n php-app
```

### Enter a Pod Shell

```bash
kubectl exec -it <pod-name> -n php-app -- bash
```

### Delete a Pod

```bash
kubectl delete pod <pod-name> -n php-app
```

### Scale Deployment

```bash
kubectl scale deployment php-app --replicas=5 -n php-app
```

## Step 18 - Rolling Update

Build a new image:

```bash
buildah bud -t php-crud-app:v2 .
```

Export the new image:

```bash
buildah push php-crud-app:v2 docker-archive:/mnt/k8s-share/php-crud-app-v2.tar
```

Import the image on all nodes:

```bash
sudo ctr -n k8s.io images import /mnt/k8s-share/php-crud-app-v2.tar
```

Update the deployment image:

```bash
kubectl set image deployment/php-app php-app=php-crud-app:v2 -n php-app
```

### Watch rollout

```bash
kubectl rollout status deployment/php-app -n php-app
```

### Rollback

```bash
kubectl rollout undo deployment/php-app -n php-app
```

## Troubleshooting

### IMAGE_PULL_BACKOFF

- Verify the image exists on each node:

```bash
sudo ctr -n k8s.io images ls
```

- Ensure the deployment uses the local image pull policy:

```yaml
imagePullPolicy: Never
```

### MySQL CrashLoopBackOff

- Check MySQL logs:

```bash
kubectl logs deployment/mysql -n php-app
```

- Fix NFS permissions if needed:

```bash
sudo chmod -R 777 /mnt/k8s-share/mysql-data
```

### PVC Pending

- Check the PersistentVolume status:

```bash
kubectl get pv
```

- Check the PersistentVolumeClaim status:

```bash
kubectl get pvc -n php-app
```

### PHP cannot connect to MySQL

- Verify MySQL-related environment variables in the PHP pod:

```bash
kubectl exec -it deployment/php-app -n php-app -- env | grep MYSQL
```

- Verify the PHP service and MySQL service are available:

```bash
kubectl get svc -n php-app
```

## Kubernetes Concepts Practiced

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