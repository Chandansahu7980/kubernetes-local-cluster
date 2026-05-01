# 03 - Node Setup (Master & Worker Preparation)

This document covers the preparation steps required on **all nodes (master and workers)** before installing Kubernetes.

---

## 📌 Why This Step is Required

Kubernetes requires:

* Swap to be disabled
* Container runtime to be installed
* Kernel networking settings to be configured

If skipped:

* `kubeadm init/join` may fail
* `kubelet` may not start
* Pod networking may break

---

## 🧪 Step 1: Disable Swap

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

### 🧠 Why?

Kubernetes expects full control over memory.
Swap can cause:

* Unpredictable scheduling
* Performance issues

---

## 🧪 Step 2: Enable Required Kernel Modules

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

## 🧪 Step 3: Configure Sysctl (Networking)

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

### 🧠 Why?

These settings allow:

* Pod-to-pod communication
* Proper network routing between nodes

---

## 🧪 Step 4: Install Container Runtime (containerd)

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

### 🧠 Why containerd?

* Lightweight container runtime
* CRI-compliant
* Used by Kubernetes (replaces Docker shim)

---

## 🧪 Step 5: Install Kubernetes Components

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
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | \
sudo tee /etc/apt/sources.list.d/kubernetes.list
```

---

### Install kubeadm, kubelet, kubectl

```bash
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
```

---

### Prevent Automatic Updates

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

---

### Verify Installation

```bash
kubeadm version
kubelet --version
kubectl version --client
```

---

### 🧠 Why Hold Versions?

Prevents:

* Unintended upgrades
* Version mismatch between cluster components

---

## ⚠️ Common Issues & Troubleshooting

### ❌ Swap Not Disabled

* `kubeadm init` fails

### ❌ SystemdCgroup Not Enabled

* `kubelet` crashes or fails to start

### ❌ Missing Kernel Settings

* Pod networking issues

---

## 🎯 Outcome

After completing these steps:

* Node is ready for Kubernetes
* Master node can run `kubeadm init`
* Worker nodes can run `kubeadm join`

---

## 📚 Key Learnings

* Kubernetes depends heavily on system-level configuration
* Container runtime is mandatory
* Networking setup is critical for cluster communication
* Version consistency is important for stability
