# 05 - Pod Networking (Calico Setup)

This document explains how to install **Calico CNI (Container Network Interface)** to enable pod networking in the Kubernetes cluster.

---

## 📌 Why Networking is Required

After running `kubeadm init`:

```bash
kubectl get nodes
```

You will see:

```text
master   NotReady
```

### 🧠 Reason:

* Kubernetes cluster is created
* BUT pods cannot communicate yet
* No network layer exists

---

## 🧠 What is CNI?

CNI (Container Network Interface) is responsible for:

* Pod-to-pod communication
* Pod-to-node communication
* Network routing across nodes

---

## 🚀 Why Calico?

Calico is a popular CNI because:

* Simple to install
* Scalable
* Uses BGP / IP routing (no overlay required in basic setup)
* Widely used in production

---

## 🧪 Step 1: Install Calico

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

---

## 🧪 Step 2: Verify Pods

```bash
kubectl get pods -n kube-system
```

---

### 📌 Expected Output

* `calico-node` → Running (on each node)
* `calico-kube-controllers` → Running
* `coredns` → Running (previously Pending)

---

## 🧪 Step 3: Verify Node Status

```bash
kubectl get nodes
```

---

### 📌 Expected

```text
master   Ready
```

---

### 🧠 What Changed?

Before Calico:

* Node = NotReady
* CoreDNS = Pending

After Calico:

* Node = Ready
* CoreDNS = Running

---

## 🧠 How Calico Works (Simplified)

* Assigns IP to each pod
* Creates routing between nodes
* Uses Linux networking (iptables, routes)

---

## 🔍 Useful Debug Commands

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

## ⚠️ Common Mistakes & Troubleshooting

---

### ❌ 1. Wrong Calico URL (404 Error)

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

### ❌ 2. Pod Network CIDR Mismatch

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

### ❌ 3. Node Still NotReady

Check:

```bash
kubectl get nodes
```

#### Possible Causes:

* Calico pods not running
* kubelet issues
* container runtime issue

---

### ❌ 4. Calico Pods Restarting

Check:

```bash
kubectl get pods -n kube-system
```

#### Debug:

```bash
kubectl logs <calico-node-pod> -n kube-system
```

#### Common Causes:

* insufficient CPU/RAM
* network conflict
* wrong kernel settings

---

### ❌ 5. CoreDNS Stuck in Pending

```bash
kubectl get pods -n kube-system
```

#### Cause:

* No CNI installed

#### Fix:

* Install Calico correctly

---

### ❌ 6. TLS Handshake Timeout

```bash
kubectl get pods
```

#### Cause:

* API server unstable
* networking partially broken

#### Fix:

```bash
sudo systemctl restart kubelet
sudo systemctl restart containerd
```

---

## 🧠 Real Learning from This Step

* Kubernetes does NOT include networking by default
* CNI plugin is mandatory
* Node readiness depends on networking
* Pod communication depends on CNI

---

## 🎯 Outcome

After completing this step:

* Cluster networking is functional
* Pods can communicate across nodes
* CoreDNS is operational
* Cluster becomes usable

---

## 🔜 Next Step

Join worker nodes to the cluster:

```bash
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

---

## 📚 Key Learnings

* Networking is the backbone of Kubernetes
* Calico enables cross-node communication
* Most “NotReady” issues are network-related