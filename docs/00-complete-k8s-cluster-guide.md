# Kubernetes Vagrant Cluster Guide

## Overview

This document combines the full lab content from the `docs/` folder into a single, end-to-end Kubernetes cluster guide for the Vagrant-based environment.

It covers:
- Environment setup
- Vagrant cluster creation
- Node preparation
- kubeadm initialization
- Calico networking
- Joining worker nodes
- Deployments and Services
- kube-proxy and iptables
- ConfigMaps and Secrets
- Persistent storage with PV/PVC
- StatefulSets and Headless Services
- NFS file storage
- Ingress concepts and setup

---

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Cluster Creation](#cluster-creation)
3. [Node Setup (Master & Worker Preparation)](#node-setup-master--worker-preparation)
4. [kubeadm Init (Master Node Setup)](#kubeadm-init-master-node-setup)
5. [Pod Networking (Calico Setup)](#pod-networking-calico-setup)
6. [Joining Worker Nodes to Cluster](#joining-worker-nodes-to-cluster)
7. [Deployments, Scaling & Services](#deployments-scaling--services)
8. [kube-proxy & iptables](#kube-proxy--iptables)
9. [ConfigMaps & Secrets](#configmaps--secrets)
10. [Persistent Volumes (Storage in Kubernetes)](#persistent-volumes-storage-in-kubernetes)
11. [MySQL with Persistent Volumes (Real-World Practice)](#mysql-with-persistent-volumes-real-world-practice)
12. [Kubernetes StatefulSet - Understanding Stateful Applications](#kubernetes-statefulset---understanding-stateful-applications)
13. [Kubernetes StatefulSet with MySQL](#kubernetes-statefulset-with-mysql)
14. [Network File System (NFS) for Kubernetes & Linux Labs](#network-file-system-nfs-for-kubernetes--linux-labs)
15. [Ingress in Kubernetes](#ingress-in-kubernetes)
16. [NGINX Ingress Controller Installation and Setup](#nginx-ingress-controller-installation-and-setup)

---

## Environment Setup

# 01 - Environment Setup

## Tools Used
- Vagrant
- VirtualBox

## Prerequisites
- Windows 10 or later
- Administrator access
- At least 6GB RAM available
- Virtualization enabled in BIOS

## Installation Steps

### Step 1: Download and Install VirtualBox

1. Visit [VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads)
2. Click on "Windows hosts" to download the installer
3. Run the downloaded `.exe` file
4. Follow the installation wizard:
   - Accept the license agreement
   - Select installation folder (default is fine)
   - Choose components (keep defaults)
   - Allow network interface installation when prompted
5. Click "Finish" and restart your computer if prompted

### Step 2: Download and Install Vagrant

1. Visit [Vagrant Downloads](https://www.vagrantup.com/downloads)
2. Download the Windows 64-bit version
3. Run the downloaded `.msi` installer
4. Follow the installation wizard:
   - Accept the license agreement
   - Choose installation directory (default is fine)
   - Click "Install"
5. Click "Finish" to complete installation
6. Restart your computer to update PATH environment variables

### Step 3: Verify Installation

Open PowerShell or Command Prompt as Administrator and run the following commands:

```powershell
# Verify VirtualBox installation
VBoxManage --version

# Verify Vagrant installation
vagrant --version

# Check Vagrant system information
vagrant --debug
```

## Expected Output

- **VirtualBox**: Should display version number (e.g., `7.0.14r161095`)
- **Vagrant**: Should display version number (e.g., `Vagrant 2.4.0`)

## Troubleshooting

- If commands not found, restart your machine or manually add Vagrant to PATH
- Ensure Hyper-V is disabled in Windows if using VirtualBox
- Check BIOS settings to enable virtualization (VT-x or AMD-V)

---

## Cluster Creation

# Cluster Initialization

## Prerequisites
- Vagrant installed on your system
- VirtualBox or another supported hypervisor
- The Vagrantfile located in the main source directory

## Cluster Specifications
The Vagrantfile creates a 3-node Kubernetes cluster with the following configuration:
- **Master node**: 4GB RAM, 2 CPUs, IP: 192.168.56.10
- **Worker1 node**: 2GB RAM, 2 CPUs, IP: 192.168.56.11
- **Worker2 node**: 2GB RAM, 2 CPUs, IP: 192.168.56.12
- **Base OS**: Ubuntu Jammy 64-bit

## Step 1: Copy Vagrantfile to Your Working Directory

If you haven't already, copy the Vagrantfile from the main source directory to your working directory:

```powershell
Copy-Item -Path ".\Vagrantfile" -Destination ".\your-working-directory\"
```

## Step 2: Start the Vagrant Machines

Navigate to the directory containing your Vagrantfile and start the Vagrant machines:

```powershell
cd e:\k8s-vagrant-cluster
vagrant up
```

This command will:
- Create 3 virtual machines (1 master, 2 workers) with Ubuntu Jammy 64-bit
- Configure private network with static IPs (192.168.56.10-12)
- Allocate specified CPU and memory resources to each node
- Display detailed logs of the initialization process

## Step 3: Verify Vagrant Machines

### Check Machine Status
Verify that all Vagrant machines are running:

```powershell
vagrant status
```

Expected output should show all three machines with status: `running`
- master
- worker1
- worker2

### SSH into Each Machine
Test connectivity to each machine:

```powershell
vagrant ssh master
vagrant ssh worker1
vagrant ssh worker2
```

### Verify Network Connectivity
Check if machines can communicate with each other:

```bash
vagrant ssh master
ping 192.168.56.11  # Ping worker1
ping 192.168.56.12  # Ping worker2
exit
```

### List Running Machines
View all running Vagrant machines on your system:

```powershell
vagrant global-status
```

### Verify Machine Resources
SSH into a machine and check allocated resources:

```bash
vagrant ssh master
free -h           # Check memory
df -h             # Check disk space
nproc             # Check CPU cores
exit
```

## Step 4: Troubleshooting

If machines fail to start:
- Check VirtualBox is installed: `vboxmanage --version`
- Review logs: `vagrant up --debug`
- Destroy and retry: `vagrant destroy -f && vagrant up`

## Next Steps
Once all machines are verified and running, proceed to cluster configuration.

---

## Node Setup (Master & Worker Preparation)

# 03 - Node Setup (Master & Worker Preparation)

This document covers the preparation steps required on **all nodes (master and workers)** before installing Kubernetes.

---

## Why This Step is Required

Kubernetes requires:

* Swap to be disabled
* Container runtime to be installed
* Kernel networking settings to be configured

If skipped:

* `kubeadm init/join` may fail
* `kubelet` may not start
* Pod networking may break

---

## Step 1: Disable Swap

### Disable Temporarily

```bash
sudo swapoff -a
```

### Disable Permanently

```bash
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

### Verify

```bash
free -h
```

### Why?

Kubernetes expects full control over memory.
Swap can cause:

* Unpredictable scheduling
* Performance issues

---

## Step 2: Enable Required Kernel Modules

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

### Persist After Reboot

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

---

## Step 3: Configure Sysctl (Networking)

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
```

### Apply Changes

```bash
sudo sysctl --system
```

### Why?

These settings allow:

* Pod-to-pod communication
* Proper network routing between nodes

---

## Step 4: Install Container Runtime (containerd)

### Install containerd

```bash
sudo apt update
sudo apt install -y containerd
```

---

### Generate Default Config

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

---

### Enable Systemd Cgroup Driver

```bash
sudo nano /etc/containerd/config.toml
```

Find:

```toml
SystemdCgroup = false
```

Change to:

```toml
SystemdCgroup = true
```

---

### Restart & Enable Service

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

---

### Verify

```bash
sudo systemctl status containerd
```

---

### Why containerd?

* Lightweight container runtime
* CRI-compliant
* Used by Kubernetes (replaces Docker shim)

---

## Step 5: Install Kubernetes Components

### Install Required Packages

```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl
```

---

### Add Kubernetes Repository

```bash
sudo mkdir -p /etc/apt/keyrings
```

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

```bash
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

```bash
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

---

### Install kubeadm, kubelet, kubectl

```bash
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
```

---

### Prevent Automatic Updates

It is recommended to prevent automatic upgrades from changing Kubernetes package versions unexpectedly.

---

## kubeadm Init (Master Node Setup)

# 04 - kubeadm Init (Master Node Setup)

This document covers initializing the Kubernetes **control-plane (master node)** using `kubeadm`.

---

## What is kubeadm?

`kubeadm` is a tool used to:

* Bootstrap a Kubernetes cluster
* Initialize control-plane components
* Generate join commands for worker nodes

---

## What Happens During `kubeadm init`?

When you run `kubeadm init`, it:

1. Starts control-plane components:
   * kube-apiserver
   * kube-controller-manager
   * kube-scheduler
   * etcd
2. Generates:
   * kubeconfig files
   * certificates
   * authentication tokens
3. Prepares the cluster for worker node joins

---

## Step 1: Run kubeadm init

```bash
sudo kubeadm init --apiserver-advertise-address=192.168.56.10 --pod-network-cidr=192.168.0.0/16
```

---

### Important Flags

| Flag                            | Purpose                              |
| ------------------------------- | ------------------------------------ |
| `--apiserver-advertise-address` | Master node IP                       |
| `--pod-network-cidr`            | Required for network plugin (Calico) |

---

## Expected Output

After successful execution, you will see:

* Cluster initialized successfully
* Instructions to configure `kubectl`
* `kubeadm join` command for workers

---

## Step 2: Configure kubectl (VERY IMPORTANT)

Run as normal user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

### Why?

Without this:

* `kubectl` cannot communicate with API server
* You will get connection errors

---

## Step 3: Verify Cluster

```bash
kubectl get nodes
```

---

### Expected Output

```text
NAME     STATUS     ROLES           AGE   VERSION
master   NotReady   control-plane   ...   v1.28.x
```

---

### Why NotReady?

Because:

* Pod network is not installed yet

---

## Step 4: Check System Pods

```bash
kubectl get pods -n kube-system
```

---

### Expected

* kube-apiserver → Running
* kube-controller-manager → Running
* kube-scheduler → Running
* etcd → Running
* coredns → Pending (before network setup)

---

## Common Issues & Troubleshooting

### Error: "connection refused"

```bash
kubectl get nodes
```

#### Cause:

* kubeconfig not set
* API server not running

#### Fix:

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

---

### API Server Restarting

Check:

```bash
sudo crictl ps
```

#### Possible Causes:

* containerd not running
* cgroup mismatch
* insufficient resources

---

### TLS Handshake Timeout

#### Cause:

* API server unstable
* network issue

#### Fix:

```bash
sudo systemctl restart kubelet
sudo systemctl restart containerd
```

---

### kubelet not stable

```bash
systemctl status kubelet
```

#### Common Reasons:

* swap not disabled
* wrong container runtime config

---

## Understanding Control Plane Components

| Component          | Role                         |
| ------------------ | ---------------------------- |
| kube-apiserver     | API server for Kubernetes    |
| kube-controller-manager | Controller loop for cluster state |
| kube-scheduler     | Schedules pods to nodes      |
| etcd               | Cluster data store           |

---

## Pod Networking (Calico Setup)

# 05 - Pod Networking (Calico Setup)

This document explains how to install **Calico CNI (Container Network Interface)** to enable pod networking in the Kubernetes cluster.

---

## Why Networking is Required

After running `kubeadm init`:

```bash
kubectl get nodes
```

You will see:

```text
master   NotReady
```

### Reason:

* Kubernetes cluster is created
* BUT pods cannot communicate yet
* No network layer exists

---

## What is CNI?

CNI (Container Network Interface) is responsible for:

* Pod-to-pod communication
* Pod-to-node communication
* Network routing across nodes

---

## Why Calico?

Calico is a popular CNI because:

* Simple to install
* Scalable
* Uses BGP / IP routing (no overlay required in basic setup)
* Widely used in production

---

## Step 1: Install Calico

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

---

## Step 2: Verify Pods

```bash
kubectl get pods -n kube-system
```

---

### Expected Output

* `calico-node` → Running (on each node)
* `calico-kube-controllers` → Running
* `coredns` → Running (previously Pending)

---

## Step 3: Verify Node Status

```bash
kubectl get nodes
```

---

### Expected

```text
master   Ready
```

---

### What Changed?

Before Calico:

* Node = NotReady
* CoreDNS = Pending

After Calico:

* Node = Ready
* CoreDNS = Running

---

## How Calico Works (Simplified)

* Assigns IP to each pod
* Creates routing between nodes
* Uses Linux networking (iptables, routes)

---

## Useful Debug Commands

```bash
kubectl get pods -n kube-system -o wide
```

```bash
kubectl describe pod <calico-pod> -n kube-system
```

```bash
kubectl logs <calico-pod> -n kube-system
```

---

## Common Mistakes & Troubleshooting

### 1. Wrong Calico URL (404 Error)

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yam
```

#### Error:

```text
404 Not Found
```

#### Fix:

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

---

### 2. Pod Network CIDR Mismatch

If you used:

```bash
kubeadm init --pod-network-cidr=192.168.0.0/16
```

Calico must match this CIDR.

#### Problem:

* Pods fail to communicate
* Network issues across nodes

#### Fix:

* Reinitialize cluster OR
* Modify Calico config (advanced)

---

### 3. Node Still NotReady

Check:

```bash
kubectl get nodes
```

#### Possible Causes:

* Calico pods not running
* kubelet issues
* container runtime issue

---

### 4. Calico Pods Restarting

Check:

```bash
kubectl get pods -n kube-system
```

#### Debug:

```bash
kubectl describe pod <calico-pod> -n kube-system
```

---

## Joining Worker Nodes to Cluster

# 06 - Joining Worker Nodes to Cluster

This document explains how to join worker nodes to the Kubernetes cluster using `kubeadm join`, along with common issues and troubleshooting.

---

## What is `kubeadm join`?

`kubeadm join` is used to:

* Add worker nodes to the cluster
* Connect nodes to the control-plane
* Enable scheduling of pods on worker nodes

---

## Prerequisites

Before joining, ensure on worker node:

* Swap is disabled ✅
* containerd is running ✅
* kubelet, kubeadm installed ✅
* Node can reach master IP ✅

---

## Step 1: Get Join Command (From Master)

Run on master:

```bash
kubeadm token create --print-join-command
```

---

### Example Output

```bash
kubeadm join 192.168.56.10:6443 \
--token abcdef.1234567890abcdef \
--discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxx
```

---

## Step 2: Run Join Command (On Worker)

```bash
sudo kubeadm join 192.168.56.10:6443 \
--token <token> \
--discovery-token-ca-cert-hash <hash>
```

---

### Important

Must run as **root (sudo)**

---

## Step 3: Verify Node (From Master)

```bash
kubectl get nodes
```

---

### Expected Output

```text
worker1   NotReady
```

---

## Why NotReady Initially?

Because:

* Calico (network plugin) is still configuring
* kubelet is initializing

👉 After some time → becomes `Ready`

---

## Step 4: Wait & Verify

```bash
kubectl get nodes -w
```

---

## What Happens Internally

When worker joins:

* kubelet registers node with API server
* certificates are exchanged
* kube-proxy starts
* Calico pod is scheduled
* networking is configured

---

## Common Errors & Troubleshooting

### 1. Error: Not Running as Root

```bash
[ERROR IsPrivilegedUser]: user is not running as root
```

#### Fix:

```bash
sudo kubeadm join ...
```

---

### 2. Node Stuck in NotReady

#### Causes:

* CNI (Calico) not ready
* kubelet not stable
* container runtime issue

#### Debug:

```bash
sudo systemctl status kubelet
```

```bash
sudo crictl ps
```

---

### 3. crictl Errors (dockershim warning)

```bash
runtime connect using default endpoints...
```

#### Reason:

* crictl checking multiple runtimes
* dockershim no longer exists

#### Fix (Optional):

```bash
sudo crictl config runtime-endpoint unix:///run/containerd/containerd.sock
```

---

### 4. kubelet Not Starting

```bash
systemctl status kubelet
```

#### Causes:

* swap not disabled
* containerd misconfigured
* missing join step

---

### 5. Worker Cannot Reach Master

#### Test:

```bash
ping 192.168.56.10
```

```bash
telnet 192.168.56.10 6443
```

#### Fix:

* Verify network connectivity
* Ensure firewalls are not blocking port 6443

---

## Deployments, Scaling & Services

# 07 - Deployments, Scaling & Services (Hands-on)

This document covers deploying an application, scaling it, exposing it using a Service, and observing Kubernetes behavior in real-time.

---

## Objective

* Deploy nginx application
* Scale replicas
* Observe pod distribution across nodes
* Expose application using NodePort
* Test load balancing
* Understand self-healing behavior

---

## Step 1: Create Deployment

```bash
kubectl create deployment nginx --image=nginx
```

---

## Step 2: Scale Deployment

```bash
kubectl scale deployment nginx --replicas=3
```

---

## Step 3: Verify Pods

```bash
kubectl get pods -o wide
```

---

### Observation

* Pods are distributed across worker nodes
* Example:
  * 2 pods on worker1
  * 1 pod on worker2

---

## Learning

Kubernetes scheduler:

* Automatically distributes workload
* Ensures high availability

---

## Step 4: Expose Deployment (NodePort)

```bash
kubectl expose deployment nginx --type=NodePort --port=80
```

---

## Step 5: Get Service Details

```bash
kubectl get svc
```

---

### Example Output

```text
nginx   NodePort   10.x.x.x   <none>   80:30007/TCP
```

---

## Step 6: Access Application

```bash
curl http://<NodeIP>:30007
```

---

### Observation

* Application is accessible from:
  * master node
  * worker nodes
  * browser

---

## How NodePort Works

* Opens a port (30000–32767) on ALL nodes
* kube-proxy handles traffic routing
* Requests are forwarded to any available pod

---

## Step 7: Verify Load Balancing

Run multiple times:

```bash
curl http://<NodeIP>:30007
```

---

### Initial Observation

* Same output every time

---

## Reason

All pods had identical nginx default page

---

## Step 8: Modify Pod Content

Logged into each pod:

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

Edited:

```bash
cd /usr/share/nginx/html
echo "Hello from POD-1" > index.html
```

---

### Observation

* Different pods return different responses
* Load balancing becomes visible

---

## Step 9: Test Load Balancing Again

```bash
curl http://<NodeIP>:30007
```

---

### Result

* Responses change randomly
* Traffic distributed across pods

---

## Learning

Kubernetes Service:

* Uses kube-proxy
* Implements load balancing
* Works at network level

---

## Step 10: Test Self-Healing

Delete a pod:

```bash
kubectl delete pod <pod-name>
```

---

### Observation

* New pod is automatically created
* Service continues working
* No downtime

---

## kube-proxy & iptables (How Traffic Actually Flows)

# 08 - kube-proxy & iptables (How Traffic Actually Flows)

This document explains how Kubernetes networking works internally using `kube-proxy` and `iptables`.

---

## Objective

* Understand how Service routes traffic
* Learn role of kube-proxy
* Inspect iptables rules
* Verify load balancing behavior

---

## What is kube-proxy?

kube-proxy runs on every node and:

* Watches Kubernetes Services & Endpoints
* Creates iptables rules
* Routes traffic to pods

---

## Key Concept

When you access:

```text
http://<NodeIP>:NodePort
```

👉 Traffic flow:

```text
NodePort → kube-proxy → iptables → Pod IP
```

---

## Step 1: Check kube-proxy Pods

```bash
kubectl get pods -n kube-system -o wide | grep kube-proxy
```

---

### Observation

* One kube-proxy pod per node
* Running on master + workers

---

## Step 2: Check Service

```bash
kubectl get svc nginx-service
```

---

## Step 3: Check Endpoints

```bash
kubectl get endpoints nginx-service
```

---

### Example Output

```text
192.168.x.x:80, 192.168.x.x:80, 192.168.x.x:80
```

---

## Meaning

* These are actual pod IPs
* kube-proxy routes traffic to these

---

## Step 4: Inspect iptables Rules

On any node:

```bash
sudo iptables -t nat -L KUBE-NODEPORTS -n
```

---

### Observation

```text
KUBE-EXT-XXXX  tcp  --  0.0.0.0/0  0.0.0.0/0  /* default/nginx-service */
```

---

## What This Means

* iptables rule created for NodePort
* Redirects traffic to service chain

---

## Step 5: Deep Inspect

```bash
sudo iptables -t nat -L -n | grep nginx
```

---

## Traffic Flow Internally

```text
NodePort (30007)
   ↓
KUBE-NODEPORTS
   ↓
KUBE-SVC-XXXX
   ↓
KUBE-SEP-XXXX
   ↓
Pod IP
```

---

## Step 6: Test Load Balancing

```bash
curl http://<NodeIP>:30007
```

Run multiple times

---

### Observation

* Different pod responses
* Confirms load balancing

---

## How Load Balancing Works

kube-proxy:

* Uses iptables random selection
* Distributes traffic across endpoints

---

## Step 7: Verify From Master Node

```bash
curl http://<WorkerIP>:30007
```

---

### Observation

* Works from ANY node

---

## Why It Works Everywhere

Because:

* kube-proxy runs on every node
* NodePort exposed on all nodes
* iptables rules exist on all nodes

---

## Quick Production Troubleshooting Commands

### Is kube-proxy running?

```bash
# Check if kube-proxy is running on all nodes
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# View kube-proxy logs for errors
kubectl logs -n kube-system -l k8s-app=kube-proxy -f
```

### Does the service have endpoints?

```bash
kubectl get endpoints nginx-service
```

---

## ConfigMaps & Secrets (Configuration Management)

# 09 - ConfigMaps & Secrets (Configuration Management)

This document explains how to manage application configuration and sensitive data using ConfigMaps and Secrets in Kubernetes.

---

## Objective

* Understand ConfigMaps
* Understand Secrets
* Inject configuration into pods
* Separate config from application code

---

## Why ConfigMaps & Secrets?

In real applications:

* Config changes frequently
* Code should NOT be modified for config
* Sensitive data must be secured

---

## Step 1: Create ConfigMap

```bash
kubectl create configmap app-config --from-literal=APP_ENV=dev
```

---

## Verify

```bash
kubectl get configmap
kubectl describe configmap app-config
```

---

## What is ConfigMap?

* Stores non-sensitive data
* Key-value pairs
* Used by pods as environment variables or files

---

## Step 2: Create Secret

```bash
kubectl create secret generic app-secret --from-literal=DB_PASSWORD=mysecret123
```

---

## Verify

```bash
kubectl get secrets
kubectl describe secret app-secret
```

---

## What is Secret?

* Stores sensitive data
* Values are base64 encoded
* Used for passwords, tokens, keys

---

## Step 3: Use ConfigMap & Secret in Deployment

Edit deployment YAML: (template.spec.containers.env)

```yaml
env:
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: APP_ENV

- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: DB_PASSWORD
```

---

## Apply Changes

```bash
kubectl apply -f nginx-deployment.yaml
```

---

## Step 4: Verify Inside Pod

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

Inside container:

```bash
echo $APP_ENV
echo $DB_PASSWORD
```

---

## Expected Output

```text
dev
mysecret123
```

---

## How It Works

* Kubernetes injects values at runtime
* No need to modify container image
* Clean separation of config and code

---

## Common Issues

### ConfigMap Not Found

```text
configmap "app-config" not found
```

### Fix:

```bash
kubectl get configmap
```

---

### Secret Not Working

#### Cause:

* Wrong key name

#### Fix:

```bash
kubectl describe secret app-secret
```

---

### Env Not Updated

#### Cause:

* Pod not restarted

#### Fix:

```bash
kubectl rollout restart deployment nginx
```

---

## Best Practices

* Use ConfigMap for non-sensitive data
* Use Secret for passwords, tokens
* Do NOT hardcode values in YAML
* Use version-controlled manifests

---

## Outcome

* Configuration separated from code
* Sensitive data handled securely
* Deployment becomes flexible

---

## Persistent Volumes (Storage in Kubernetes)

# 10 - Persistent Volumes (Storage in Kubernetes)

This document explains how Kubernetes handles storage using Persistent Volumes (PV) and Persistent Volume Claims (PVC), with a practical example of storing **nginx access logs** for better real-world understanding.

---

## Objective

* Understand PV & PVC
* Create persistent storage
* Attach storage to pods
* Store nginx access logs persistently
* Verify data persistence after pod restart

---

## Why Storage is Needed?

By default:

* Pods are **ephemeral**
* Data is lost when pod is deleted

---

## Example Problem

```text
Delete pod → Logs lost ❌
```

---

## Solution

Use:

* PersistentVolume (PV)
* PersistentVolumeClaim (PVC)

---

## Core Concepts

### Persistent Volume (PV)

* Actual storage (disk)
* Created by admin or manually
* Example: local disk, cloud disk

---

### Persistent Volume Claim (PVC)

* Request for storage
* Created by developer
* Pod uses PVC, not PV directly

---

## Flow

```text
Pod → PVC → PV → Disk
```

---

## Step 1: Create Persistent Volume

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

## Explanation

* `1Gi` → storage size
* `hostPath` → uses node's local disk
* Good for learning (not production)

---

## Apply

```bash
kubectl apply -f pv.yaml
```

---

## Step 2: Create PVC

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

## Apply

```bash
kubectl apply -f pvc.yaml
```

---

## Verify Binding

```bash
kubectl get pv
kubectl get pvc
```

---

### Expected

```text
STATUS = Bound
```

---

## Step 3: Use PVC for Nginx Access Logs

Instead of storing static files, we will store **nginx access logs**, which is a real-world use case.

---

## Default Nginx Log Path

```text
/var/log/nginx/access.log
```

---

## Update Deployment

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
```

---

## Apply

```bash
kubectl apply -f nginx-deployment.yaml
```

---

## Step 4: Generate Logs

Access your service multiple times:

```bash
curl http://<NodeIP>:30007
```

Run it multiple times to generate logs.

---

## Step 5: Verify Logs Inside Pod

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

Check logs:

```bash
cat /var/log/nginx/access.log
```

---

### Expected

```text
GET / HTTP/1.1 ...
GET / HTTP/1.1 ...
```

---

## MySQL with Persistent Volumes (Real-World Practice)

# 11 - MySQL with Persistent Volumes (Real-World Practice)

This document demonstrates running a **stateful application (MySQL)** using:

* Persistent Volumes (PV)
* Persistent Volume Claims (PVC)
* Secrets (for credentials)
* Deployment & Service

---

## Objective

* Understand PV ↔ PVC relationship
* Deploy MySQL with persistent storage
* Store real database data
* Verify data persistence after pod restart

---

## Architecture Overview

```text
MySQL Pod → PVC → PV → Node Disk
```

---

## Files Used

```text
manifests/
├── 08-mysql-pv.yaml
├── 08-mysql-pvc.yaml
├── 08-mysql-secret.yaml
├── 08-mysql-deployment.yaml
└── 08-mysql-service.yaml
```

---

## Step 1: Create Persistent Volume

```bash
kubectl apply -f manifests/08-mysql-pv.yaml
```

---

## Verify

```bash
kubectl get pv
```

---

## Step 2: Create PVC

```bash
kubectl apply -f manifests/08-mysql-pvc.yaml
```

---

## Verify Binding

```bash
kubectl get pvc
```

Expected:

```text
STATUS = Bound
```

---

## Step 3: Create Secret

```bash
kubectl apply -f manifests/08-mysql-secret.yaml
```

---

## Verify

```bash
kubectl get secret
```

---

## Step 4: Deploy MySQL

```bash
kubectl apply -f manifests/08-mysql-deployment.yaml
```

---

## Verify Pod

```bash
kubectl get pods
```

---

## Step 5: Create Service

```bash
kubectl apply -f manifests/08-mysql-service.yaml
```

---

## Verify

```bash
kubectl get svc
```

---

## Step 6: Connect to MySQL Pod

```bash
kubectl exec -it <mysql-pod-name> -- /bin/bash
```

---

## Login to MySQL

```bash
mysql -u root -p
```

Enter password (from Secret)

---

## Step 7: Create Database & Table

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

## Expected Output

```text
+----+---------+
| id | name    |
+----+---------+
|  1 | Chandan |
+----+---------+
```

---

## Step 8: Delete Pod

```bash
kubectl delete pod <mysql-pod-name>
```

---

## Step 9: Verify Persistence

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

## Expected Result

* Data persists after pod restart
* The database remains available

---

## Kubernetes StatefulSet - Understanding Stateful Applications

# Kubernetes StatefulSet - Understanding Stateful Applications

## Overview

StatefulSet is a Kubernetes workload resource designed for deploying and managing **stateful applications**.

Unlike Deployments, which are ideal for stateless workloads, StatefulSets provide:

* Stable pod identity
* Stable network identity
* Persistent storage
* Ordered deployment and scaling
* Ordered pod termination

StatefulSets are commonly used for databases, messaging systems, and distributed applications where data persistence and pod identity are critical.

---

## Why StatefulSet Was Introduced

Before StatefulSet existed, Kubernetes primarily used Deployments and ReplicaSets.

Deployments work extremely well for stateless applications such as:

* Nginx
* Apache
* Frontend applications
* REST APIs
* Microservices

However, they create challenges when deploying databases and other stateful workloads.

For example:

```text
Deployment creates:

mysql-abcd1234
mysql-efgh5678
mysql-ijkl9012
```

If a pod is deleted:

```text
mysql-abcd1234
```

Kubernetes may recreate:

```text
mysql-xyz9876
```

The new pod has:

* Different name
* Different identity
* Potentially different storage
```

This behavior is acceptable for stateless applications but problematic for databases.

---

## Problems with Deployments for Databases

Consider a MySQL database deployed using a Deployment.

### Problem 1: Unstable Pod Names

Pod names change whenever pods are recreated.

Example:

```text
Old Pod:
mysql-abcd1234

New Pod:
mysql-xyz9876
```

If a pod is recreated, its identity changes.

---

### Problem 2: Storage Management

Databases require persistent storage.

Without proper storage handling:

```text
Pod Deleted
    ↓
Storage Lost
    ↓
Data Lost
```

This is unacceptable for production databases.

---

### Problem 3: Clustered Databases

Many database systems rely on node identity.

Examples:

* MySQL Replication
* MongoDB Replica Sets
* Cassandra
* Kafka
* ZooKeeper

Each node must have a predictable hostname.
Deployments cannot guarantee this.

---

### Problem 4: Startup Order

Distributed applications often require nodes to start in sequence.

Example:

```text
Database Primary
      ↓
Database Replica
      ↓
Application
```

Deployments start pods in parallel and do not guarantee ordering.

---

## How StatefulSet Solves These Problems

StatefulSet introduces the concept of pod identity.

Instead of random pod names:

```text
mysql-abcd1234
mysql-efgh5678
```

StatefulSet creates:

```text
mysql-0
mysql-1
mysql-2
```

These names never change.

---

## Stable Pod Identity

Each pod gets a predictable name.

Example:

```text
mysql-0
mysql-1
mysql-2
```

If mysql-0 crashes:

```text
mysql-0 deleted
```

Kubernetes recreates:

```text
mysql-0
```

The identity remains unchanged.

---

## Stable Network Identity

StatefulSet works together with a Headless Service.

This provides DNS records such as:

```text
mysql-0.mysql-headless
mysql-1.mysql-headless
mysql-2.mysql-headless
```

Applications can always locate a specific pod.

---

## Persistent Storage

Each StatefulSet pod receives its own PersistentVolumeClaim.

Example:

```text
mysql-0
  └── pvc-mysql-0

mysql-1
  └── pvc-mysql-1

mysql-2
  └── pvc-mysql-2
```

Even if a pod is deleted:

```text
mysql-0 deleted
```

The storage remains:

```text
pvc-mysql-0
```

When mysql-0 is recreated, Kubernetes automatically reattaches the same storage.

This ensures data persistence.

---

## Kubernetes StatefulSet with MySQL (PV, PVC, Headless Service)

# 🗄️ Kubernetes StatefulSet with MySQL (PV, PVC, Headless Service)

## Overview

This document demonstrates how to deploy a **stateful MySQL database** in Kubernetes using:

* StatefulSet
* PersistentVolume (PV)
* PersistentVolumeClaim (PVC)
* Headless Service
* Secret (for password management)

---

## Key Concepts

### StatefulSet

* Provides **stable pod identity**
* Example pod names:

```text
mysql-0
mysql-1
```

---

### PersistentVolume (PV)

* Represents actual storage in the cluster
* Manually created in local setup (hostPath)

---

### PersistentVolumeClaim (PVC)

* Requests storage from PV
* Automatically created by StatefulSet

---

### Headless Service

```yaml
clusterIP: None
```

* No load balancing
* Provides **direct DNS to pods**

---

## Manifest Files

```
manifests/
├── mysql-secret.yaml
├── mysql-statefulset-pv.yaml
├── mysql-headless-service.yaml
└── mysql-statefulset.yaml
```

---

## 1. Create Secret

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

## 2. Create PersistentVolume

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

### Important

Create directory on node:

```bash
sudo mkdir -p /mnt/data/mysql-pv
sudo chmod -R 777 /mnt/data
```

---

## 3. Create Headless Service

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

## 4. Deploy StatefulSet

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

## Verification Steps

### 1. Check Pods

```bash
kubectl get pods -o wide
```

Expected:

```
mysql-0   Running
```

---

### 2. Check PVC

```bash
kubectl get pvc
```

Expected:

```
mysql-storage-mysql-0   Bound
```

---

### 3. Check PV

```bash
kubectl get pv
```

Expected:

```
mysql-pv   Bound
```

---

### 4. Check Service

```bash
kubectl get svc
```

Expected:

```
mysql-headless   ClusterIP: None
```

---

## Access MySQL

Use `kubectl exec` to connect to the container and verify the database is running.

---

## Network File System (NFS) for Kubernetes & Linux Labs

# Network File System (NFS) for Kubernetes & Linux Labs

![Linux](https://img.shields.io/badge/Linux-NFS-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Shared%20Storage-green)
![Storage](https://img.shields.io/badge/Storage-Network%20File%20System-orange)

---

## Table of Contents

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

## What is NFS?

### NFS (Network File System)

NFS is a distributed file system protocol that allows one Linux server to share directories and files with other systems over a network.

It enables remote systems to access shared storage as if it were a local filesystem.

---

## Why NFS is Required

In distributed environments like Kubernetes, multiple servers or containers may require access to the same data.

Without shared storage:

- Data becomes node-dependent
- Files exist only on one machine
- Pods lose data when rescheduled
- Scaling applications becomes difficult

NFS solves this by providing centralized shared storage accessible from multiple systems simultaneously.

---

## How NFS Works

NFS works using a client-server model.

### NFS Server

The server:

- Hosts the shared directory
- Exports filesystem paths
- Manages access permissions
- Handles remote file requests

---

### NFS Client

The client:

- Connects to the NFS server
- Mounts remote directories
- Accesses files like local storage

---

## NFS Workflow

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
|-------------------|
| /mnt/shared         |
+-------------------+
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

## Real Production Use Cases

NFS is widely used in enterprise environments.

---

### 1. Kubernetes Persistent Storage

Used for:

- Persistent Volumes (PV)
- Shared pod storage
- Stateful applications

Example:

```text
Multiple pods accessing shared uploads directory
```

---

### 2. Shared Application Storage

Application servers share:

- Configuration files
- Static assets
- Common libraries

---

### 3. CI/CD Pipelines

Build servers share:

- Artifacts
- Logs
- Deployment packages

---

### 4. Backup Systems

Centralized storage for:

- Server backups
- Database dumps
- Snapshots

---

### 5. Media & Content Platforms

Shared storage for:

- Videos
- Images
- Media streaming

---

## NFS Architecture

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

## NFS Components

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

## NFS Versions

| Version | Features |
|---|---|
| NFSv3 | Stateless, older version |
| NFSv4 | Secure, stateful, firewall-friendly |

---

## Ingress in Kubernetes

# Ingress in Kubernetes

## Overview

Ingress is a Kubernetes resource that manages external access to services inside a cluster.

It acts as a central entry point for HTTP and HTTPS traffic and provides routing rules to direct requests to the appropriate services.

Ingress solves the problem of exposing multiple applications without creating separate NodePorts or LoadBalancers for each application.

---

## Why Ingress Was Introduced

Before Ingress, applications were typically exposed using:

* NodePort
* LoadBalancer

Example:

```text
PHP Application    -> NodePort 30080
Grafana            -> NodePort 30081
Prometheus         -> NodePort 30082
Jenkins            -> NodePort 30083
```

Users would access applications using:

```text
http://192.168.56.10:30080
http://192.168.56.10:30081
http://192.168.56.10:30082
```

Problems:

* Difficult to remember ports
* Not scalable
* Requires one NodePort per application
* LoadBalancer services can become expensive in cloud environments
* No centralized traffic management

Kubernetes introduced Ingress to solve these challenges.

---

## What Problem Does Ingress Solve?

Ingress provides:

* Single entry point for applications
* Host-based routing
* Path-based routing
* HTTPS/TLS termination
* Centralized traffic management
* Reduced operational complexity

Instead of:

```text
app.company.com:30080
grafana.company.com:30081
jenkins.company.com:30082
```

Users can access:

```text
app.company.com
grafana.company.com
jenkins.company.com
```

using standard HTTP (80) and HTTPS (443).

---

## Kubernetes Networking Components

Understanding the difference between Service and Ingress is very important.

### Service

A Service exposes Pods inside the cluster and provides load balancing.

Example:

```text
php-service
    |
    +---- php-pod-1
    +---- php-pod-2
    +---- php-pod-3
```

A Service decides:

> Which Pod should receive traffic?

---

### Ingress

Ingress routes external traffic to Services.

Example:

```text
crud.local
     |
     +---- php-service

grafana.local
     |
     +---- grafana-service
```

An Ingress decides:

> Which Service should receive traffic?

---

## What is an Ingress Controller?

Ingress itself is only a set of routing rules.
It does not process traffic.

An Ingress Controller is responsible for:

* Reading Ingress resources
* Processing requests
* Routing traffic to backend services

Popular Ingress Controllers:

* NGINX Ingress Controller
* Traefik
* HAProxy
* Kong
* AWS ALB Controller

The most commonly used controller is:

```text
NGINX Ingress Controller
```

---

## Ingress vs Ingress Controller

### Ingress

Contains routing rules.

Example:

```yaml
kind: Ingress
```

Defines:

```text
crud.local -> php-service
grafana.local -> grafana-service
```

---

### Ingress Controller

Actual software running inside Kubernetes.
Usually deployed as Pods.

Responsible for:

* Listening on HTTP/HTTPS ports
* Reading Ingress resources
* Routing requests to services

---

## Traffic Flow Without Ingress

```text
Browser
   |
NodePort Service
   |
Pods
```

Example:

```text
192.168.56.10:30080
```

---

## Traffic Flow With Ingress

```text
Browser
   |
Ingress Controller
   |
Service
   |
Pods
```

Example:

```text
crud.local
```

---

## Host-Based Routing

Ingress can route traffic based on hostname.

Example:

```text
crud.local
grafana.local
prometheus.local
```

Traffic Flow:

```text
Browser
    |
    |
NGINX Ingress Controller
    |
    +---- crud.local
    |          |
    |      php-service
    |
    +---- grafana.local
    |          |
    |      grafana-service
    |
    +---- prometheus.local
               |
         prometheus-service
```

---

## Example Host-Based Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: platform-ingress

spec:
  ingressClassName: nginx

  rules:

  - host: crud.local

    http:
      paths:
      - path: /
        pathType: Prefix

        backend:
          service:
            name: php-service

            port:
              number: 80

  - host: grafana.local

    http:
      paths:
      - path: /
        pathType: Prefix

        backend:
          service:
            name: grafana-service

            port:
              number: 3000
```

---

## Path-Based Routing

Ingress can also route traffic using URL paths.

Example:

```text
company.local/
company.local/grafana
company.local/prometheus
```

Traffic Flow:

```text
company.local
      |
      +---- /
      |       |
      |   php-service
      |
      +---- /grafana
      |       |
      |   grafana-service
      |
      +---- /prometheus
              |
        prometheus-service
```

---

## Example Path-Based Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: company-ingress

spec:
  ingressClassName: nginx

  rules:

  - host: company.local

    http:
      paths:

      - path: /
        pathType: Prefix

        backend:
          service:
            name: php-service

            port:
              number: 80

      - path: /grafana
        pathType: Prefix

        backend:
          service:
            name: grafana-service

            port:
              number: 3000
```

---

## How DNS Works With Ingress

Hosts file example:

```text
192.168.56.10 crud.local
192.168.56.10 grafana.local
192.168.56.10 prometheus.local
```

All hostnames point to the same IP address.

Ingress Controller examines the HTTP Host header and forwards traffic to the correct service.

Example:

```http
Host: grafana.local
```

---

## NGINX Ingress Controller Installation and Setup

# NGINX Ingress Controller Installation and Setup

## Overview

In this lab, we install the NGINX Ingress Controller in a Kubernetes cluster and expose applications using Ingress resources.

The goal is to access applications using hostnames instead of NodePorts.

Before:

http://192.168.56.10:30080

After:

http://crud.local

---

## Lab Architecture

Browser
   |
crud.local
   |
Ingress Controller
   |
php-service
   |
PHP Pods

The Ingress Controller acts as a reverse proxy and routes incoming traffic to the correct Kubernetes Service.

---

## Prerequisites

Ensure the following are already configured:

* Kubernetes Cluster (kubeadm)
* Calico CNI
* kubectl configured
* Working application deployed
* Existing Service exposing the application

Verify:

```bash
kubectl get nodes
kubectl get pods -A
```

All nodes and pods should be healthy.

---

## Step 1: Install NGINX Ingress Controller

For bare-metal or Vagrant-based Kubernetes clusters:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
```

---

## Step 2: Verify Installation

Check namespace:

```bash
kubectl get ns
```

Expected:

`ingress-nginx`

Check pods:

```bash
kubectl get pods -n ingress-nginx
```

Example:

NAME                                        READY   STATUS
ingress-nginx-controller-xxxxxx             1/1     Running
ingress-nginx-admission-create-xxxxx        0/1     Completed
ingress-nginx-admission-patch-xxxxx         0/1     Completed

Check deployments:

```bash
kubectl get deployment -n ingress-nginx
```

Expected:

NAME                       READY
ingress-nginx-controller   1/1

Check services:

```bash
kubectl get svc -n ingress-nginx
```

Example:

NAME                       TYPE       PORT(S)
ingress-nginx-controller   NodePort   80:31234/TCP,443:31443/TCP

---

## Step 3: Verify Controller Logs

Check controller logs:

```bash
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

Expected:

Starting NGINX Ingress controller

This confirms the controller is watching Kubernetes resources.

---

## Step 4: Inspect Created Resources

View everything created by the installation:

```bash
kubectl get all -n ingress-nginx
```

Observe:

Deployment
ReplicaSet
Pods
Services
Jobs

This demonstrates that the Ingress Controller itself is just another Kubernetes application.

---

## Step 5: Understand the Controller Service

Check:

```bash
kubectl get svc -n ingress-nginx
```

Example:

NAME                       TYPE       PORT(S)
ingress-nginx-controller   NodePort   80:31234/TCP,443:31443/TCP

Explanation:

| Port | Purpose |
|------|---------|
| 80   | HTTP Traffic |
| 443  | HTTPS Traffic |
| NodePort | External Access |

Traffic enters the cluster through this service.

---

## Step 6: Verify Existing Application Service

Example:

```bash
kubectl get svc -n pro2
```

Output:

NAME           TYPE       PORT(S)
php-service    NodePort   80:30080/TCP

Ensure the application is already accessible before creating Ingress.

Verify endpoints:

```bash
kubectl get endpoints php-service -n pro2
```

Example:

NAME          ENDPOINTS
php-service   10.244.1.5:80

---

## Step 7: Create Ingress Resource

Create:

```yaml
# php-ingress.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: php-ingress
  namespace: pro2

spec:
  ingressClassName: nginx

  rules:

  - host: crud.local

    http:
      paths:

      - path: /
        pathType: Prefix

        backend:
          service:
            name: php-service

            port:
              number: 80
```

Apply:

```bash
kubectl apply -f php-ingress.yaml
```

---

## Step 8: Verify Ingress Resource

Check:

```bash
kubectl get ingress -n pro2
```

Expected:

NAME          CLASS   HOSTS
php-ingress   nginx   crud.local

Describe Ingress:

```bash
kubectl describe ingress php-ingress -n pro2
```

Verify:

Host:
crud.local

Backend:
php-service:80

---

## Step 9: Configure Local DNS Resolution

On Windows:

Open:

`C:\Windows\System32\drivers\etc\hosts`

Add:

```text
192.168.56.10 crud.local
```

Replace IP with your Kubernetes node IP if different.

Save the file.

Verify:

```bash
ping crud.local
```

Expected:

Pinging crud.local [192.168.56.10]

---

## Step 10: Determine Ingress Controller Port

Check:

```bash
kubectl get svc -n ingress-nginx
```

Example:

NAME                       TYPE       PORT(S)
ingress-nginx-controller   NodePort   80:31234/TCP

Ingress Controller NodePort:

31234

Your value may differ.

---

## Step 11: Access Application Through Ingress

Open browser:

http://crud.local:31234

Expected:

Application should load successfully.

Traffic flow:

Browser
   |
crud.local:31234
   |
Ingress Controller
   |
php-service
   |
PHP Pods

---

## Common Verification Commands

Check Ingress:

```bash
kubectl get ingress -A
```

Check Services:

```bash
kubectl get svc -A
```

Check Endpoints:

```bash
kubectl get endpoints -A
```

Check Controller Pods:

```bash
kubectl get pods -n ingress-nginx
```

Check Controller Logs:

```bash
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

---

## Troubleshooting

### Ingress Not Created

Verify:

```bash
kubectl get ingress -A
```

Check for YAML errors:

```bash
kubectl describe ingress <ingress-name>
```

---

### Controller Not Running

Check:

```bash
kubectl get pods -n ingress-nginx
```

Review logs:

```bash
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

---

### Service Has No Endpoints

Check:

```bash
kubectl get endpoints <service-name>
```

No endpoints usually indicate:

* Pod labels mismatch
* Service selector mismatch

---

### Hostname Not Resolving

Verify hosts file:

```text
192.168.56.10 crud.local
```

Test:

```bash
ping crud.local
```

---

### Application Returns 404

Verify:

```bash
kubectl describe ingress php-ingress -n pro2
```

Check:

* Hostname
* Service name
* Service port
