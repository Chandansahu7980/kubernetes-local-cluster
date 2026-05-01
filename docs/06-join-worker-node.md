# 06 - Joining Worker Nodes to Cluster

This document explains how to join worker nodes to the Kubernetes cluster using `kubeadm join`, along with common issues and troubleshooting.

---

## 📌 What is `kubeadm join`?

`kubeadm join` is used to:

* Add worker nodes to the cluster
* Connect nodes to the control-plane
* Enable scheduling of pods on worker nodes

---

## 🧠 Prerequisites

Before joining, ensure on worker node:

* Swap is disabled ✅
* containerd is running ✅
* kubelet, kubeadm installed ✅
* Node can reach master IP ✅

---

## 🧪 Step 1: Get Join Command (From Master)

Run on master:

```bash id="4x1lgc"
kubeadm token create --print-join-command
```

---

### 📌 Example Output

```bash id="p4zzlj"
kubeadm join 192.168.56.10:6443 \
--token abcdef.1234567890abcdef \
--discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxx
```

---

## 🧪 Step 2: Run Join Command (On Worker)

```bash id="0lgxks"
sudo kubeadm join 192.168.56.10:6443 \
--token <token> \
--discovery-token-ca-cert-hash <hash>
```

---

### ⚠️ Important

Must run as **root (sudo)**

---

## 🧪 Step 3: Verify Node (From Master)

```bash id="d1n6gq"
kubectl get nodes
```

---

### 📌 Expected Output

```text id="0g0p3x"
worker1   NotReady
```

---

## 🧠 Why NotReady Initially?

Because:

* Calico (network plugin) is still configuring
* kubelet is initializing

👉 After some time → becomes `Ready`

---

## 🧪 Step 4: Wait & Verify

```bash id="rr7cn3"
kubectl get nodes -w
```

---

## 🔍 What Happens Internally

When worker joins:

* kubelet registers node with API server
* certificates are exchanged
* kube-proxy starts
* Calico pod is scheduled
* networking is configured

---

## ⚠️ Common Errors & Troubleshooting

---

### ❌ 1. Error: Not Running as Root

```bash id="gxkkzd"
[ERROR IsPrivilegedUser]: user is not running as root
```

#### Fix:

```bash id="3o8gbn"
sudo kubeadm join ...
```

---

### ❌ 2. Node Stuck in NotReady

```bash id="8mdhrp"
kubectl get nodes
```

#### Causes:

* CNI (Calico) not ready
* kubelet not stable
* container runtime issue

---

#### Debug:

```bash id="a4y9o9"
sudo systemctl status kubelet
```

```bash id="r7e5jj"
sudo crictl ps
```

---

### ❌ 3. crictl Errors (dockershim warning)

```bash id="iy3b2o"
runtime connect using default endpoints...
```

#### 🧠 Reason:

* crictl checking multiple runtimes
* dockershim no longer exists

#### Fix (Optional):

```bash id="u2u3fk"
sudo crictl config runtime-endpoint unix:///run/containerd/containerd.sock
```

---

### ❌ 4. kubelet Not Starting

```bash id="xlgz8h"
systemctl status kubelet
```

#### Causes:

* swap not disabled
* containerd misconfigured
* missing join step

---

### ❌ 5. Worker Cannot Reach Master

#### Test:

```bash id="w0v9s8"
ping 192.168.56.10
```

```bash id="x7c0nj"
telnet 192.168.56.10 6443
```

#### Fix:

* check network connectivity
* firewall rules
* correct IP

---

### ❌ 6. Token Expired

#### Error:

```text id="fqksgi"
token is invalid or expired
```

#### Fix:

```bash id="0zx0py"
kubeadm token create --print-join-command
```

---

## 🧪 Step 5: Verify Pods on Worker

```bash id="x52r4r"
kubectl get pods -o wide
```

---

### 📌 Expected

Pods distributed across:

* worker1
* worker2

---

## 🧠 Real Observations

* Nodes may take time to become Ready
* kube-proxy starts before full readiness
* Calico pod is critical for networking
* Some warnings (like crictl) are normal

---

## 🎯 Outcome

After this step:

* Worker nodes are part of cluster
* Pods can be scheduled on workers
* Load balancing across nodes is possible

---

## 📚 Key Learnings

* `kubeadm join` connects node to cluster
* Node readiness depends on networking
* kubelet plays a critical role
* Troubleshooting is essential in real setups

---

## 🔜 Next Step

Deploy application & expose it:

* Create Deployment
* Scale replicas
* Create Service (NodePort)