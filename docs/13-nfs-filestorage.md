# Network File System (NFS) for Kubernetes & Linux Labs

![Linux](https://img.shields.io/badge/Linux-NFS-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Shared%20Storage-green)
![Storage](https://img.shields.io/badge/Storage-Network%20File%20System-orange)

---

# Table of Contents

- What is NFS?
- Why NFS is Required
- How NFS Works
- Real Production Use Cases
- NFS Architecture
- NFS Components
- NFS Versions
- Advantages and Limitations
- NFS Best Practices
- Secure NFS Configuration
- Step-by-Step NFS Server Setup
- Step-by-Step NFS Client Setup
- Persistent Mount Configuration
- Important Mount Options
- Kubernetes Use Cases
- Useful NFS Commands
- Troubleshooting Guide
- Common Errors and Solutions
- Performance Optimization Tips
- Security Recommendations

---

# What is NFS?

## NFS (Network File System)

NFS is a distributed file system protocol that allows one Linux server to share directories and files with other systems over a network.

It enables remote systems to access shared storage as if it were a local filesystem.

---

# Why NFS is Required

In distributed environments like Kubernetes, multiple servers or containers may require access to the same data.

Without shared storage:

- Data becomes node-dependent
- Files exist only on one machine
- Pods lose data when rescheduled
- Scaling applications becomes difficult

NFS solves this by providing centralized shared storage accessible from multiple systems simultaneously.

---

# How NFS Works

NFS works using a client-server model.

## NFS Server

The server:

- Hosts the shared directory
- Exports filesystem paths
- Manages access permissions
- Handles remote file requests

---

## NFS Client

The client:

- Connects to the NFS server
- Mounts remote directories
- Accesses files like local storage

---

# NFS Workflow

```text
+---------------------+
|     NFS SERVER      |
|---------------------|
| /srv/nfs/shared     |
+----------+----------+
           |
           | Network
           |
+----------+----------+
|     NFS CLIENT      |
|---------------------|
| /mnt/shared         |
+---------------------+
```

The client mounts the remote directory:

```bash
mount -t nfs <server-ip>:/srv/nfs/shared /mnt/shared
```

After mounting:

- Reading files
- Writing files
- Creating directories

all happen over the network.

---

# Real Production Use Cases

NFS is widely used in enterprise environments.

---

# 1. Kubernetes Persistent Storage

Used for:

- Persistent Volumes (PV)
- Shared pod storage
- Stateful applications

Example:

```text
Multiple pods accessing shared uploads directory
```

---

# 2. Shared Application Storage

Application servers share:

- Configuration files
- Static assets
- Common libraries

---

# 3. CI/CD Pipelines

Build servers share:

- Artifacts
- Logs
- Deployment packages

---

# 4. Backup Systems

Centralized storage for:

- Server backups
- Database dumps
- Snapshots

---

# 5. Media & Content Platforms

Shared storage for:

- Videos
- Images
- Media streaming

---

# NFS Architecture

```text
                   +------------------+
                   |    NFS SERVER    |
                   |------------------|
                   | Shared Directory |
                   +--------+---------+
                            |
                ------------------------
                |                      |
      +---------+---------+  +---------+---------+
      |     CLIENT 1      |  |     CLIENT 2      |
      |-------------------|  |-------------------|
      | Mounted NFS Share |  | Mounted NFS Share |
      +-------------------+  +-------------------+
```

---

# NFS Components

| Component | Purpose |
|---|---|
| NFS Server | Exports shared storage |
| NFS Client | Mounts shared storage |
| `nfs-kernel-server` | NFS server package |
| `nfs-common` | NFS client package |
| `rpcbind` | RPC communication service |
| `exportfs` | Export management utility |
| `showmount` | View exported shares |

---

# NFS Versions

| Version | Features |
|---|---|
| NFSv3 | Stateless, older version |
| NFSv4 | Secure, stateful, firewall-friendly |

---

# Recommended Version

Use:

```text
NFSv4
```

because it provides:

- Better security
- Improved performance
- Better locking
- Simplified firewall configuration

---

# Advantages of NFS

✅ Centralized storage  
✅ Shared access across systems  
✅ Easy setup  
✅ Lightweight solution  
✅ Useful for Kubernetes labs  
✅ Simplifies backup management  

---

# Limitations of NFS

❌ Network dependent  
❌ Performance limited by network speed  
❌ Single point of failure without HA  
❌ Not ideal for heavy database workloads  

---

# NFS Best Practices

---

# 1. Use Dedicated Shared Directories

Recommended:

```bash
/srv/nfs/shared
```

Avoid exporting:

```bash
/home
/root
/
```

---

# 2. Use Static IP Addresses

NFS exports depend on client access rules.

Static IPs ensure reliable mounting.

---

# 3. Use NFSv4

Recommended mount option:

```bash
vers=4
```

---

# 4. Restrict Client Access

Bad Practice:

```bash
*(rw,sync)
```

Good Practice:

```bash
192.168.56.0/24(rw,sync)
```

---

# 5. Avoid `no_root_squash` in Production

Lab environments may use:

```bash
no_root_squash
```

Production environments should use:

```bash
root_squash
```

to prevent remote root privilege escalation.

---

# 6. Use Persistent Mounts

Configure mounts in:

```bash
/etc/fstab
```

with:

```bash
_netdev,nofail
```

---

# 7. Use Proper Permissions

Recommended:

```bash
chmod 775
```

Avoid:

```bash
chmod 777
```

unless for temporary lab testing.

---

# 8. Monitor Disk Usage

Monitor:

- Storage utilization
- Network latency
- File locks
- Mount health

---

# Secure NFS Configuration

---

# Recommended Export Example

```bash
/srv/nfs/shared 192.168.56.0/24(rw,sync,root_squash,no_subtree_check)
```

---

# Export Option Explanation

| Option | Description |
|---|---|
| rw | Read/write access |
| ro | Read-only access |
| sync | Immediate write confirmation |
| async | Faster but less safe |
| root_squash | Restrict remote root user |
| no_root_squash | Allow remote root access |
| no_subtree_check | Improves reliability |

---

# Step-by-Step NFS Server Setup

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

# Step 3: Set Ownership and Permissions

Recommended secure permissions:

```bash
sudo chown nobody:nogroup /srv/nfs/shared
sudo chmod 775 /srv/nfs/shared
```

---

# Step 4: Configure Exports

Edit:

```bash
sudo vi /etc/exports
```

Add:

```bash
/srv/nfs/shared 192.168.56.0/24(rw,sync,root_squash,no_subtree_check)
```

---

# Step 5: Apply Exports

```bash
sudo exportfs -rav
```

---

# Step 6: Enable and Start Services

```bash
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server
```

---

# Step 7: Verify Exports

```bash
sudo exportfs -v
```

---

# Step-by-Step NFS Client Setup

---

# Step 1: Install NFS Client Package

```bash
sudo apt update
sudo apt install nfs-common -y
```

---

# Step 2: Create Mount Directory

```bash
sudo mkdir -p /mnt/nfs/shared
```

---

# Step 3: Mount NFS Share

```bash
sudo mount -t nfs -o vers=4 <server-ip>:/srv/nfs/shared /mnt/nfs/shared
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

Edit:

```bash
sudo vi /etc/fstab
```

Add:

```bash
<server-ip>:/srv/nfs/shared /mnt/nfs/shared nfs defaults,_netdev,nofail,vers=4 0 0
```

---

# Test fstab

```bash
sudo mount -a
```

---

# Important Mount Options

| Option | Purpose |
|---|---|
| defaults | Default mount settings |
| _netdev | Wait for network before mounting |
| nofail | Boot continues even if mount fails |
| vers=4 | Use NFSv4 |
| soft | Timeout on server failure |
| hard | Retry indefinitely |
| timeo | Timeout value |

---

# Kubernetes Use Cases

NFS is commonly used in Kubernetes for:

- Persistent Volumes
- Shared pod storage
- Stateful applications
- Shared logs
- Shared uploads

---

# Example Kubernetes Scenario

```text
Pod A writes file -> Shared NFS Storage
Pod B reads same file -> Shared NFS Storage
```

This enables persistent shared data across worker nodes.

---

# Useful NFS Commands

---

# Check NFS Exports

```bash
showmount -e <server-ip>
```

---

# Verify Export Configuration

```bash
exportfs -v
```

---

# Reload Exports

```bash
sudo exportfs -rav
```

---

# Check Mounted Shares

```bash
mount | grep nfs
```

---

# Check Disk Usage

```bash
df -h
```

---

# Verify RPC Services

```bash
rpcinfo -p
```

---

# Check NFS Service Status

```bash
systemctl status nfs-kernel-server
```

---

# Restart NFS Service

```bash
sudo systemctl restart nfs-kernel-server
```

---

# View Logs

```bash
journalctl -xe
```

---

# Troubleshooting Guide

---

# Verify Connectivity

```bash
ping <server-ip>
```

---

# Verify Export Visibility

```bash
showmount -e <server-ip>
```

---

# Verify Mount

```bash
mount | grep nfs
```

---

# Check Firewall Rules

```bash
sudo ufw status
```

---

# Common Errors and Solutions

---

# Error: Access Denied by Server

## Cause

Client IP not allowed in exports.

## Solution

Verify:

```bash
/etc/exports
```

Reapply:

```bash
sudo exportfs -rav
```

---

# Error: Connection Timed Out

## Cause

- Firewall blocked
- Service down
- Network issue

## Solution

Check:

```bash
systemctl status nfs-kernel-server
```

and:

```bash
ping <server-ip>
```

---

# Error: Stale File Handle

## Cause

NFS export changed or server restarted.

## Solution

```bash
sudo umount -f /mnt/nfs/shared
sudo mount -a
```

---

# Error: Permission Denied

## Cause

Filesystem permission mismatch.

## Solution

Check:

```bash
ls -ld /srv/nfs/shared
```

Update permissions:

```bash
sudo chmod 775 /srv/nfs/shared
```

---

# Error: Mount Fails After Reboot

## Cause

Network unavailable during startup.

## Solution

Use:

```bash
_netdev,nofail
```

inside `/etc/fstab`

---

# Performance Optimization Tips

---

# Use Dedicated Storage Network

Production environments often use:

- Separate VLAN
- Dedicated NIC
- Storage network isolation

---

# Use Async Carefully

```bash
async
```

Improves performance but risks data loss during crashes.

---

# Tune Read/Write Buffers

Example:

```bash
rsize=8192,wsize=8192
```

---

# Security Recommendations

✅ Use NFSv4  
✅ Restrict client IPs  
✅ Avoid `no_root_squash`  
✅ Use firewalls  
✅ Use dedicated storage directories  
✅ Monitor access logs  
✅ Backup NFS data regularly  
✅ Use read-only exports when possible  

---