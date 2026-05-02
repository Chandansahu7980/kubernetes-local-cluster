# 08 - kube-proxy & iptables (How Traffic Actually Flows)

This document explains how Kubernetes networking works internally using `kube-proxy` and `iptables`.

---

## 📌 Objective

* Understand how Service routes traffic
* Learn role of kube-proxy
* Inspect iptables rules
* Verify load balancing behavior

---

## 🧠 What is kube-proxy?

kube-proxy runs on every node and:

* Watches Kubernetes Services & Endpoints
* Creates iptables rules
* Routes traffic to pods

---

## 🧠 Key Concept

When you access:

```text id="l7zslx"
http://<NodeIP>:NodePort
```

👉 Traffic flow:

```text id="3d7q7q"
NodePort → kube-proxy → iptables → Pod IP
```

---

## 🧪 Step 1: Check kube-proxy Pods

```bash id="3v2o0u"
kubectl get pods -n kube-system -o wide | grep kube-proxy
```

---

### 📌 Observation

* One kube-proxy pod per node
* Running on master + workers

---

## 🧪 Step 2: Check Service

```bash id="4sh1re"
kubectl get svc nginx-service
```

---

## 🧪 Step 3: Check Endpoints

```bash id="qrrx7d"
kubectl get endpoints nginx-service
```

---

### 📌 Example Output

```text id="tcm8yn"
192.168.x.x:80, 192.168.x.x:80, 192.168.x.x:80
```

---

## 🧠 Meaning

* These are actual pod IPs
* kube-proxy routes traffic to these

---

## 🧪 Step 4: Inspect iptables Rules

On any node:

```bash id="q2j7h1"
sudo iptables -t nat -L KUBE-NODEPORTS -n
```

---

### 📌 Observation

```text id="r6vcqt"
KUBE-EXT-XXXX  tcp  --  0.0.0.0/0  0.0.0.0/0  /* default/nginx-service */
```

---

## 🧠 What This Means

* iptables rule created for NodePort
* Redirects traffic to service chain

---

## 🧪 Step 5: Deep Inspect

```bash id="6v6qzp"
sudo iptables -t nat -L -n | grep nginx
```

---

## 🧠 Traffic Flow Internally

```text id="2hz7jz"
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

## 🧪 Step 6: Test Load Balancing

```bash id="3z9fmi"
curl http://<NodeIP>:30007
```

Run multiple times

---

### 📌 Observation

* Different pod responses
* Confirms load balancing

---

## 🧠 How Load Balancing Works

kube-proxy:

* Uses iptables random selection
* Distributes traffic across endpoints

---

## 🧪 Step 7: Verify From Master Node

```bash id="9snqrd"
curl http://<WorkerIP>:30007
```

---

### 📌 Observation

* Works from ANY node

---

## 🧠 Why It Works Everywhere

Because:

* kube-proxy runs on every node
* NodePort exposed on all nodes
* iptables rules exist on all nodes

---

## 🛠️ Quick Production Troubleshooting Commands

### ✅ Is kube-proxy running?

```bash
# Check if kube-proxy is running on all nodes
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# View kube-proxy logs for errors
kubectl logs -n kube-system -l k8s-app=kube-proxy -f
```

### ✅ Does the service have endpoints?

```bash
# Check if service has any endpoints
kubectl get endpoints <service-name> -n <namespace>

# View detailed endpoint info
kubectl describe endpoints <service-name> -n <namespace>

# Verify pods match service selector
kubectl get pods -l <label-key>=<label-value> -n <namespace> -o wide
```

### ✅ Are iptables rules created?

```bash
# Check if rules exist for the service
sudo iptables -t nat -L KUBE-NODEPORTS -n | grep <service-port>

# View all Kubernetes NAT rules
sudo iptables -t nat -L -n | grep KUBE

# Check specific NodePort rule
sudo iptables -t nat -L -n | grep :<node-port>
```

### ✅ Test connectivity

```bash
# Test from node to service (ClusterIP)
curl http://<SERVICE-CLUSTER-IP>:<SERVICE-PORT>

# Test NodePort from external
curl http://<NODE-IP>:<NODE-PORT>

# Test from inside a pod
kubectl exec -it <pod-name> -n <namespace> -- curl http://<SERVICE-NAME>:<PORT>

# Test DNS resolution inside pod
kubectl exec -it <pod-name> -n <namespace> -- nslookup <service-name>
```

### ✅ Debug a failing service

```bash
# 1. Check if service exists and has correct selector
kubectl describe svc <service-name> -n <namespace>

# 2. Verify pods are running and match selector
kubectl get pods -l <label-key>=<label-value> -n <namespace> -o wide

# 3. Check kube-proxy pod logs for errors
kubectl logs -n kube-system -l k8s-app=kube-proxy | tail -50

# 4. Verify iptables rules exist
sudo iptables -t nat -L -n | grep <service-port>

# 5. Test pod-to-pod connectivity directly
kubectl exec -it <source-pod> -n <namespace> -- curl http://<target-pod-ip>:<port>

# 6. Check if NodePort listening on node
sudo netstat -tuln | grep <node-port>
```

---

## ⚠️ Common Issues

---

### ❌ Same Response Every Time

#### Cause:

* Pods identical

#### Fix:

* Modify content in each pod

---

### ❌ NodePort Not Working

#### Causes:

* wrong node IP
* kube-proxy not running

---

### ❌ iptables Rules Missing

```bash id="zz5vny"
sudo iptables -t nat -L
```

#### Fix:

* restart kube-proxy
* restart kubelet

---

## 🧠 Real Learning

* Kubernetes networking is not magic
* kube-proxy translates Service → iptables
* iptables does actual routing
* Services are virtual abstraction

---

## 🎯 Outcome

* Understood real traffic flow
* Verified iptables rules
* Confirmed load balancing mechanism

---

## 📚 Key Learnings

* kube-proxy = rule generator
* iptables = traffic handler
* Service = abstraction layer

---

## 🔜 Next Step

* ConfigMaps & Secrets
* Proper application configuration