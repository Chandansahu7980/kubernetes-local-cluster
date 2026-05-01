# 04 - kubeadm Init (Master Node Setup)

This document covers initializing the Kubernetes **control-plane (master node)** using `kubeadm`.

---

## 📌 What is kubeadm?

`kubeadm` is a tool used to:

* Bootstrap a Kubernetes cluster
* Initialize control-plane components
* Generate join commands for worker nodes

---

## 🧠 What Happens During `kubeadm init`?

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

## 🧪 Step 1: Run kubeadm init

```bash
sudo kubeadm init --apiserver-advertise-address=192.168.56.10 --pod-network-cidr=192.168.0.0/16
```

---

### 🧠 Important Flags

| Flag                            | Purpose                              |
| ------------------------------- | ------------------------------------ |
| `--apiserver-advertise-address` | Master node IP                       |
| `--pod-network-cidr`            | Required for network plugin (Calico) |

---

## 📌 Expected Output

After successful execution, you will see:

* Cluster initialized successfully
* Instructions to configure `kubectl`
* `kubeadm join` command for workers

---

## 🧪 Step 2: Configure kubectl (VERY IMPORTANT)

Run as normal user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

### 🧠 Why?

Without this:

* `kubectl` cannot communicate with API server
* You will get connection errors

---

## 🧪 Step 3: Verify Cluster

```bash
kubectl get nodes
```

---

### 📌 Expected Output

```text
NAME     STATUS     ROLES           AGE   VERSION
master   NotReady   control-plane   ...   v1.28.x
```

---

### 🧠 Why NotReady?

Because:

* Pod network is not installed yet

---

## 🧪 Step 4: Check System Pods

```bash
kubectl get pods -n kube-system
```

---

### 📌 Expected

* kube-apiserver → Running
* kube-controller-manager → Running
* kube-scheduler → Running
* etcd → Running
* coredns → Pending (before network setup)

---

## ⚠️ Common Issues & Troubleshooting

---

### ❌ Error: "connection refused"

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

### ❌ API Server Restarting

Check:

```bash
sudo crictl ps
```

#### Possible Causes:

* containerd not running
* cgroup mismatch
* insufficient resources

---

### ❌ TLS Handshake Timeout

#### Cause:

* API server unstable
* network issue

#### Fix:

```bash
sudo systemctl restart kubelet
sudo systemctl restart containerd
```

---

### ❌ kubelet not stable

```bash
systemctl status kubelet
```

#### Common Reasons:

* swap not disabled
* wrong container runtime config

---

## 🧠 Understanding Control Plane Components

| Component          | Role                         |
| ------------------ | ---------------------------- |
| kube-apiserver     | Entry point for all commands |
| etcd               | Stores cluster state         |
| scheduler          | Assigns pods to nodes        |
| controller-manager | Maintains desired state      |

---

## 🎯 Outcome

After this step:

* Master node is initialized
* Control-plane is running
* Ready to install networking (Calico)
* Ready for worker nodes to join

---

## 📚 Key Learnings

* Kubernetes control plane runs as static pods
* kubelet manages these pods
* API server is the heart of Kubernetes
* Cluster is unusable until networking is configured

---

## 🔜 Next Step

Install Pod Networking (Calico):

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

---

After networking:

* Node becomes `Ready`
* CoreDNS starts running
