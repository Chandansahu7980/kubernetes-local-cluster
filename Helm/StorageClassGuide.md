# Mastering Dynamic Storage in Kubernetes: StorageClass & NFS

A comprehensive guide covering the fundamentals of Kubernetes `StorageClass`, the transition from static to dynamic provisioning, and a complete hands-on lab using an NFS server and Helm.

---

## 1. What is a StorageClass?

A **StorageClass** in Kubernetes is a cluster resource that describes a class of storage. Different classes can represent different performance tiers, backup policies, retention behavior, or other storage policies defined by administrators.

A StorageClass is similar to an automated storage provisioner plugin. Instead of manually creating storage volumes every time an application requests storage, the StorageClass automatically provisions the physical volume on demand.

---

## 2. Why Was It Introduced & What Does It Solve?

### The Old Way: Static Provisioning 🐌

Before StorageClasses, teams used **static provisioning**:

1. An administrator manually created a network share or cloud disk.
2. The administrator wrote a `PersistentVolume` (PV) YAML manifest for that exact volume.
3. A developer created a `PersistentVolumeClaim` (PVC) requesting storage.
4. Kubernetes matched the PVC to a pre-created PV.

**The bottleneck:** If a developer needed a 5Gi disk and no matching PV existed, the claim would remain `Pending`. Every storage request required manual intervention and did not scale well.

### The New Way: Dynamic Provisioning ⚡

StorageClasses enable **dynamic provisioning**:

* Administrators define a `StorageClass` once, pointing it to a storage backend provisioner (for example, AWS EBS, Google Persistent Disk, or an NFS provisioner).
* Developers create a `PersistentVolumeClaim` (PVC).
* Kubernetes uses the `StorageClass` to provision the storage automatically, create a `PersistentVolume`, and bind it to the claim.

This removes the need for pre-created PVs and lets storage be provisioned on demand.

---

## 3. Architecture Overview

When an application requests persistent storage, Kubernetes processes it through three layers:

1. **PersistentVolumeClaim (PVC):** The application request for storage (for example, "8Gi with ReadWriteOnce").
2. **StorageClass:** The definition of how to provision volumes, including which provisioner/driver to use.
3. **PersistentVolume (PV):** The actual storage volume created dynamically to satisfy the claim.

---

## 4. Hands-On Lab: Implementing NFS Dynamic Storage Using Helm

This guide shows how to configure an NFS server on a master node and use Helm to deploy an NFS subdirectory provisioner that dynamically creates storage for PVCs.

### Environment Requirements

* **Master Node IP:** The internal cluster IP address of your master node.
* **NFS Share Directory:** `/srv/nfs/shared`

---

### Step 1: Configure the NFS Server on the Master Node

Log into the master node and install the NFS server packages.

```bash
sudo apt-get update
sudo apt-get install nfs-kernel-server -y
sudo mkdir -p /srv/nfs/shared
sudo chmod -R 777 /srv/nfs/shared
sudo chown -R nobody:nogroup /srv/nfs/shared

echo "/srv/nfs/shared 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
```

> Replace `10.0.0.0/24` with your actual Vagrant or internal host network range.

---

### Step 2: Install NFS Client Support on Worker Nodes

On each worker node, install the NFS client driver so pods can mount NFS shares.

```bash
sudo apt-get update
sudo apt-get install nfs-common -y
```

---

### Step 3: Deploy the NFS Subdirectory Provisioner with Helm

From your local machine with `helm` and `kubectl` configured, install the NFS provisioner chart.

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update

helm install nfs-storage nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<MASTER_NODE_IP> \
  --set nfs.path=/srv/nfs/shared \
  --set storageClass.name=nfs-client \
  --set storageClass.defaultClass=true
```

> Replace `<MASTER_NODE_IP>` with the actual internal IP of your master node.

Setting `storageClass.defaultClass=true` makes this StorageClass the default for PVCs that do not specify a class name.

---

### Step 4: Verify the Provisioner and StorageClass

Check that the StorageClass exists and is marked as default.

```bash
kubectl get storageclass
```

Expected output:

```text
NAME                   PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   AGE
nfs-client (default)   k8s-sigs.io/nfs-subdir-external-provisioner     Delete          Immediate           1m
```

Check that the provisioner pod is running:

```bash
kubectl get pods -l app=nfs-subdir-external-provisioner
```

---

### Step 5: Test the Workflow with a PVC

Create a PVC manifest named `test-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Apply the claim:

```bash
kubectl apply -f test-pvc.yaml
kubectl get pvc
```

If everything is configured correctly, the claim should be `Bound` and a dynamic PV will be created.

Example output:

```text
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-nfs-pvc   Bound    pvc-8a531138-1a09-4e7e-a963-fbec5ecd0a41   1Gi        RWO            nfs-client     5s
```
