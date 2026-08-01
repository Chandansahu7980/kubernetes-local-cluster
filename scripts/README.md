# Kubernetes 3-Node Lab Cluster — Vagrant Automation

Automated Kubernetes lab cluster using **Vagrant + VirtualBox + Ubuntu 22.04 + containerd + kubeadm + Calico**.

The setup creates one control-plane node and two worker nodes with minimal manual configuration.

---

## 🏗️ Cluster Architecture

```text
                         Kubernetes Cluster
                                │
                ┌───────────────┴───────────────┐
                │                               │
        ┌───────▼────────┐              ┌───────▼────────┐
        │     master     │              │     Calico     │
        │ Control Plane  │              │      CNI       │
        │ 192.168.56.10  │              └────────────────┘
        └───────┬────────┘
                │
       ┌────────┴────────┐
       │                 │
┌──────▼───────┐ ┌──────▼───────┐
│   worker1    │ │   worker2    │
│192.168.56.11 │ │192.168.56.12 │
└──────────────┘ └──────────────┘
```

### Environment

| Component          | Configuration     |
| ------------------ | ----------------- |
| OS                 | Ubuntu 22.04      |
| Kubernetes         | v1.28.15          |
| Runtime            | containerd        |
| CNI                | Calico            |
| Control Plane      | 1                 |
| Workers            | 2                 |
| Network            | `192.168.56.0/24` |
| VirtualBox Network | `vboxnet0`        |
| Master             | `192.168.56.10`   |
| Worker1            | `192.168.56.11`   |
| Worker2            | `192.168.56.12`   |

---

## 📁 Project Structure

```text
k8s-vagrant-cluster/
│
├── Vagrantfile
│
├── scripts/
│   ├── 01-common.sh
│   ├── 02-master.sh
│   ├── 03-worker.sh
│   ├── 04-init-cluster.sh
│   ├── 05-install-calico.sh
│   ├── 06-join-worker.sh
│   ├── 07-output.log
│   └── README.md
│
├── data/
├── manifests/
├── docs/
└── README.md
```

---

# ⚙️ Automation Scripts

### `01-common.sh`

Runs on **all nodes**.

Responsible for common Kubernetes prerequisites such as:

* System preparation
* Swap configuration
* Required packages
* Containerd installation/configuration
* Kubernetes repository
* kubeadm
* kubelet
* kubectl
* Basic node preparation

---

### `02-master.sh`

Runs only on the **master**.

Prepares the control-plane node for Kubernetes initialization.

---

### `03-worker.sh`

Runs on **worker1 and worker2**.

Prepares worker nodes to join the Kubernetes cluster.

---

### `04-init-cluster.sh`

Runs on the **master**.

Responsible for:

* `kubeadm init`
* Control-plane configuration
* kubeconfig configuration
* Root kubectl access
* Vagrant kubectl access
* Kubernetes API verification

Both users can therefore use:

```bash
kubectl get nodes
```

Root:

```text
/root/.kube/config
```

Vagrant:

```text
/home/vagrant/.kube/config
```

---

### `05-install-calico.sh`

Installs and validates the **Calico CNI**.

The script is designed to be more reliable by checking:

* Kubernetes API availability
* Existing Calico installation
* Existing CRDs
* Cluster readiness
* Calico node status
* Node IP detection

This is particularly important in a multi-interface Vagrant environment where Kubernetes may detect the NAT IP (`10.0.2.x`) instead of the intended host-only IP (`192.168.56.x`).

---

### `06-join-worker.sh`

Runs on worker nodes.

Responsible for:

* Obtaining the worker join command
* Joining worker nodes to the control plane
* Avoiding unnecessary re-joining if the node is already part of the cluster

After successful execution:

```bash
kubectl get nodes -o wide
```

should show:

```text
NAME      STATUS   ROLES           INTERNAL-IP
master    Ready    control-plane   192.168.56.10
worker1   Ready    <none>          192.168.56.11
worker2   Ready    <none>          192.168.56.12
```

---

# 🚀 Quick Start

## 1. Check VirtualBox Host-Only Network

```powershell
VBoxManage list hostonlyifs
```

Make sure the host-only adapter exists and uses:

```text
192.168.56.1/24
```

---

## 2. Validate Vagrantfile

```powershell
vagrant validate
```

Expected:

```text
Vagrantfile validated successfully.
```

---

## 3. Start the Cluster

```powershell
vagrant up
```

Provisioning will configure:

```text
master
worker1
worker2
```

---

## 4. Check VM Status

```powershell
vagrant status
```

---

## 5. Connect to Master

```powershell
vagrant ssh master
```

Then:

```bash
kubectl get nodes -o wide
```

---

## 6. Verify System Pods

```bash
kubectl get pods -n kube-system -o wide
```

Check Calico:

```bash
kubectl get pods -n kube-system -l k8s-app=calico-node
```

---

# 🔄 Re-Provisioning

If a script is modified:

```powershell
vagrant provision master
```

For a specific worker:

```powershell
vagrant provision worker1
```

Or provision everything:

```powershell
vagrant provision
```

If a VM needs to be restarted:

```powershell
vagrant reload master
```

---

# 🧹 Recreate the Entire Lab

If the cluster becomes corrupted or the VMs need to be recreated:

```powershell
vagrant destroy -f
vagrant up
```

This creates a fresh cluster using the automation.

---

# 🩺 Troubleshooting

## 1. `vagrant ssh` → Permission denied (publickey)

If Windows reports:

```text
Permission denied (publickey)
```

Check:

```powershell
vagrant ssh master -- -v
```

If OpenSSH reports:

```text
UNPROTECTED PRIVATE KEY FILE
Bad permissions
```

the Vagrant private key permissions need to be corrected.

Check:

```powershell
Get-ChildItem "$env:USERPROFILE\.vagrant.d\insecure_private_keys"
```

Then correct the permissions of the affected key.

---

## 2. VM timeout during boot

Example:

```text
Timed out while waiting for the machine to boot
```

Check:

```powershell
vagrant status
```

If the VM is running, try:

```powershell
vagrant reload worker2
```

or:

```powershell
vagrant up worker2
```

---

## 3. `kubectl` tries `localhost:8080`

Example:

```text
The connection to the server localhost:8080 was refused
```

This normally means kubeconfig is missing for the current user.

Check:

```bash
echo $KUBECONFIG
ls -l ~/.kube/config
```

For the Vagrant user:

```bash
ls -l /home/vagrant/.kube/config
```

The automation configures kubeconfig for both:

```text
root
vagrant
```

---

## 4. Calico detects `10.0.2.15`

Vagrant creates two networks:

```text
NAT       → 10.0.2.x
Host-only → 192.168.56.x
```

Kubernetes/Calico may initially detect the NAT interface.

Verify:

```bash
kubectl get nodes -o wide
```

Check Calico's detected IP:

```bash
kubectl get node master -o yaml | grep -A5 "projectcalico.org"
```

Expected:

```text
projectcalico.org/IPv4Address: 192.168.56.10/24
```

---

## 5. Calico `isCIDR(self)` error

Possible error:

```text
undeclared reference to 'isCIDR'
```

This can occur when the Calico manifest requires a Kubernetes/CEL validation capability that isn't compatible with the cluster version.

Do not repeatedly reinstall Calico blindly.

First check:

```bash
kubectl get pods -n kube-system
kubectl get crd | grep -E 'calico|tigera'
```

Also check whether Calico resources were partially created.

The automated Calico script performs checks before installation to make the provisioning process safer.

---

## 6. Kubernetes API not ready during provisioning

Check:

```bash
kubectl get nodes
```

Then:

```bash
kubectl get pods -n kube-system
```

Check kubelet:

```bash
sudo systemctl status kubelet
```

Check containerd:

```bash
sudo systemctl status containerd
```

---

# 🔍 Useful Commands

### Cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get namespaces
```

### Control Plane

```bash
kubectl get pods -n kube-system
kubectl get componentstatuses
```

### Calico

```bash
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl get crd | grep calico
kubectl get ippools.crd.projectcalico.org
```

### Node Information

```bash
ip addr
ip route
hostname -I
```

### Services

```bash
sudo systemctl status kubelet
sudo systemctl status containerd
```

### Kubernetes Configuration

```bash
kubectl config view
kubectl config current-context
```

---

# 📂 Vagrant Shared Folder

The project can share:

```text
./data
```

with the VMs:

```text
/vagrant/data
```

Verify:

```bash
ls -la /vagrant/data
```

Test from one node:

```bash
echo "test" > /vagrant/data/test.txt
```

Then verify from another node.

> This is a Vagrant/VirtualBox shared folder for the lab. It is not Kubernetes PV/PVC storage.

---

# 🎯 What This Automation Provides

After `vagrant up`, the goal is to have:

```text
✓ 3 Ubuntu VMs
✓ 1 Kubernetes control plane
✓ 2 Kubernetes workers
✓ containerd runtime
✓ kubeadm/kubelet/kubectl
✓ Calico CNI
✓ Correct node networking
✓ Automatic worker joining
✓ kubeconfig for root and vagrant
✓ Repeatable cluster recreation
✓ Idempotent provisioning checks
```

---

# 🔜 Next Steps

This cluster is now ready for Kubernetes learning and practical labs.
---

## 📝 Note

This project is intended for **learning and lab purposes**.

The configuration uses Vagrant, VirtualBox, host-only networking, and local storage to make Kubernetes concepts easy to reproduce and troubleshoot.
