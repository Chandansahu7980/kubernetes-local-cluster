# Kubernetes Local Vagrant Cluster with NFS Shared Storage

![Kubernetes](https://img.shields.io/badge/Kubernetes-Local%20Lab-blue)
![Vagrant](https://img.shields.io/badge/Vagrant-VirtualBox-orange)
![NFS](https://img.shields.io/badge/Storage-NFS-green)

---

# Overview

This project demonstrates how to configure a simple **NFS (Network File System)** setup inside a local Kubernetes lab environment created using:

- Vagrant
- VirtualBox
- Kubernetes
- Ubuntu/Linux
- NFS Server

The goal is to solve the problem of **node-local storage** in Kubernetes by creating a **shared storage location** accessible from multiple worker nodes.

---

# Problem Statement

Initially, pod data was stored locally on the node where the pod was running.

This caused several issues:

- Data was tied to a specific node
- If pod moved to another worker node, data was unavailable
- No centralized shared storage
- Difficult to simulate production-style shared persistence

Example Problem:

```text
Pod scheduled on worker1 -> data available
Pod rescheduled to worker2 -> data missing
```

---

# Solution

To solve this problem, NFS was configured:

- Master node acts as NFS Server
- Worker nodes act as NFS Clients
- Shared directory exported from master node
- Same directory mounted on worker nodes

This allows:

✅ Shared storage across worker nodes  
✅ Consistent data access  
✅ Simulated production-like shared filesystem  
✅ Easier Kubernetes persistent storage testing  

---

# Lab Architecture

```text
                    +----------------------+
                    |      MASTER NODE     |
                    |----------------------|
                    | 192.168.56.10        |
                    | NFS SERVER           |
                    | /srv/nfs/shared      |
                    +----------+-----------+
                               |
             -----------------------------------------
             |                                       |
             |                                       |
+------------+-----------+          +----------------+-----------+
|       WORKER1          |          |       WORKER2              |
|------------------------|          |----------------------------|
| 192.168.56.11          |          | 192.168.56.12              |
| Mounts NFS Share       |          | Mounts NFS Share           |
| /srv/nfs/shared        |          | /srv/nfs/shared            |
+------------------------+          +----------------------------+
```

---

# Vagrant Cluster Configuration

```ruby
nodes = [
  { name: "master",  ip: "192.168.56.10", cpu: 3, memory: 4096 },
  { name: "worker1", ip: "192.168.56.11", cpu: 2, memory: 2048 },
  { name: "worker2", ip: "192.168.56.12", cpu: 2, memory: 2048 }
]
```

---

# What is NFS?

## NFS (Network File System)

NFS is a distributed file system protocol that allows systems to share directories over a network.

It enables multiple machines to access the same filesystem remotely as if it were local storage.

---

# Why Use NFS in Kubernetes Lab?

NFS helps simulate real-world shared storage systems used in production environments.

Common production examples:

- Shared application storage
- Kubernetes Persistent Volumes
- CI/CD artifact storage
- Shared logs
- Media storage
- Backup systems

---

# NFS Components

| Component | Purpose |
|---|---|
| NFS Server | Shares/export directories |
| NFS Client | Mounts shared directory |
| nfs-kernel-server | Server package |
| nfs-common | Client package |

---

# Environment Details

| Node | Role | IP Address |
|---|---|---|
| master | NFS Server + Control Plane | 192.168.56.10 |
| worker1 | Kubernetes Worker | 192.168.56.11 |
| worker2 | Kubernetes Worker | 192.168.56.12 |

---

# NFS Server Configuration (Master Node)

---

# Step 1: Install NFS Server

## Ubuntu/Debian

```bash
sudo apt update
sudo apt install nfs-kernel-server -y
```

---

# Step 2: Create Shared Directory

```bash
sudo mkdir -p /srv/nfs/shared
```

---

# Step 3: Set Permissions

```bash
sudo chmod -R 777 /srv/nfs/shared
sudo chown nobody:nogroup /srv/nfs/shared
```

---

# Step 4: Configure NFS Export

Edit exports file:

```bash
sudo vi /etc/exports
```

Add:

```bash
/srv/nfs/shared 192.168.56.11(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/shared 192.168.56.12(rw,sync,no_subtree_check,no_root_squash)
```

---

# Export Options Explained

| Option | Description |
|---|---|
| rw | Read and write access |
| sync | Write changes immediately |
| no_subtree_check | Improves reliability |
| no_root_squash | Allows root access from client |

---

# Step 5: Apply Export Configuration

```bash
sudo exportfs -rav
```

---

# Step 6: Enable and Start NFS Service

```bash
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server
```

---

# Verify NFS Export

```bash
sudo exportfs -v
```

---

# NFS Client Configuration (Worker Nodes)

Perform on both worker nodes.

---

# Step 1: Install NFS Client Package

```bash
sudo apt update
sudo apt install nfs-common -y
```

---

# Step 2: Create Mount Directory

```bash
sudo mkdir -p /srv/nfs/shared
```

---

# Step 3: Mount NFS Share

```bash
sudo mount -t nfs 192.168.56.10:/srv/nfs/shared /srv/nfs/shared
```

---

# Step 4: Verify Mount

```bash
df -h
```

or

```bash
mount | grep nfs
```

---

# Persistent Mount Configuration

To automatically mount after reboot:

Edit:

```bash
sudo vi /etc/fstab
```

Add:

```bash
192.168.56.10:/srv/nfs/shared/ /srv/nfs/shared nfs defaults,_netdev,nofail 0 0
```

---

# Test fstab Configuration

```bash
sudo mount -a
```

If no errors appear, configuration is correct.

---

# Verify Shared Storage

## On worker1

```bash
echo "hello from worker1" > /srv/nfs/shared/test.txt
```

---

## On worker2

```bash
cat /srv/nfs/shared/test.txt
```

Expected Output:

```text
hello from worker1
```

This confirms shared storage is working.

---

# Kubernetes Use Case

NFS can later be used for:

- Persistent Volumes (PV)
- Persistent Volume Claims (PVC)
- Shared pod storage
- Stateful workloads

Example scenarios:

- Shared uploads directory
- Shared application logs
- Shared config storage

---

# Important Commands for Troubleshooting

---

# Check NFS Service Status

```bash
sudo systemctl status nfs-kernel-server
```

---

# Verify Exports

```bash
sudo exportfs -v
```

---

# Show Available Exports from Client

```bash
showmount -e 192.168.56.10
```

---

# Verify Mounted Filesystems

```bash
mount | grep nfs
```

---

# Check Disk Usage

```bash
df -h
```

---

# Restart NFS Service

```bash
sudo systemctl restart nfs-kernel-server
```

---

# Reload Exports

```bash
sudo exportfs -rav
```

---

# Check RPC Services

```bash
rpcinfo -p
```

---

# View System Logs

```bash
journalctl -xe
```

---

# Common Errors and Solutions

---

# Error 1: Access Denied by Server

## Error

```text
mount.nfs: access denied by server
```

## Cause

Client IP not allowed in `/etc/exports`

## Solution

Verify exports:

```bash
cat /etc/exports
```

Reapply:

```bash
sudo exportfs -rav
```

---

# Error 2: Connection Timed Out

## Cause

- Firewall issue
- NFS service not running
- Network connectivity problem

## Solution

Check service:

```bash
systemctl status nfs-kernel-server
```

Check connectivity:

```bash
ping 192.168.56.10
```

---

# Error 3: Mount Fails After Reboot

## Cause

Network unavailable during boot

## Solution

Use:

```bash
_netdev,nofail
```

inside `/etc/fstab`

---

# Error 4: Stale File Handle

## Cause

Server restarted or export changed

## Solution

Unmount and remount:

```bash
sudo umount -f /srv/nfs/shared
sudo mount -a
```

---

# Error 5: Permission Denied

## Cause

Linux filesystem permissions mismatch

## Solution

Update permissions:

```bash
sudo chmod -R 777 /srv/nfs/shared
```

---

# Security Notes

Current lab setup uses:

```bash
no_root_squash
```

This is acceptable for local labs/testing.

However, in production environments:

❌ Avoid `no_root_squash`  
✅ Prefer `root_squash`  
✅ Restrict subnet access  
✅ Use firewall rules  
✅ Use NFSv4  

---

# Production Best Practices

## Recommended

✅ Use dedicated storage nodes  
✅ Use NFSv4  
✅ Use RAID-backed storage  
✅ Restrict client IP access  
✅ Monitor disk usage  
✅ Configure backups  
✅ Use Kubernetes StorageClass  

---

# Useful Commands Cheat Sheet

| Command | Purpose |
|---|---|
| `showmount -e <server-ip>` | Show NFS exports |
| `exportfs -v` | Verify exports |
| `mount -t nfs` | Mount NFS share |
| `mount | grep nfs` | Check mounted shares |
| `df -h` | Verify storage |
| `rpcinfo -p` | Check RPC services |
| `journalctl -xe` | View logs |
| `systemctl status nfs-kernel-server` | NFS service status |

---

# Final Result

After setup:

✅ Worker nodes share the same filesystem  
✅ Data persists across nodes  
✅ Shared Kubernetes storage simulation achieved  
✅ Better understanding of distributed storage concepts  

---

# Future Improvements

Possible next steps:

- Configure Kubernetes Persistent Volumes
- Create NFS StorageClass
- Dynamic provisioning
- Use external NFS server
- Implement high availability storage

---

# Conclusion

This setup provides a simple and effective way to simulate shared storage in a local Kubernetes lab environment using NFS.

It helps understand:

- Distributed storage concepts
- Kubernetes persistence
- Shared filesystem architecture
- Production-like infrastructure behavior

This is an excellent foundation before moving to advanced storage solutions such as:

- Ceph
- Longhorn
- GlusterFS
- Cloud storage solutions

---