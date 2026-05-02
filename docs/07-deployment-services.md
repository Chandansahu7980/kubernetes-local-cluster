# 07 - Deployments, Scaling & Services (Hands-on)

This document covers deploying an application, scaling it, exposing it using a Service, and observing Kubernetes behavior in real-time.

---

## 📌 Objective

* Deploy nginx application
* Scale replicas
* Observe pod distribution across nodes
* Expose application using NodePort
* Test load balancing
* Understand self-healing behavior

---

## 🧪 Step 1: Create Deployment

```bash
kubectl create deployment nginx --image=nginx
```

---

## 🧪 Step 2: Scale Deployment

```bash
kubectl scale deployment nginx --replicas=3
```

---

## 🧪 Step 3: Verify Pods

```bash
kubectl get pods -o wide
```

---

### 📌 Observation

* Pods are distributed across worker nodes
* Example:

  * 2 pods on worker1
  * 1 pod on worker2

---

## 🧠 Learning

Kubernetes scheduler:

* Automatically distributes workload
* Ensures high availability

---

## 🧪 Step 4: Expose Deployment (NodePort)

```bash
kubectl expose deployment nginx --type=NodePort --port=80
```

---

## 🧪 Step 5: Get Service Details

```bash
kubectl get svc
```

---

### 📌 Example Output

```text
nginx   NodePort   10.x.x.x   <none>   80:30007/TCP
```

---

## 🧪 Step 6: Access Application

```bash
curl http://<NodeIP>:30007
```

---

### 📌 Observation

* Application is accessible from:

  * master node
  * worker nodes
  * browser

---

## 🧠 How NodePort Works

* Opens a port (30000–32767) on ALL nodes
* kube-proxy handles traffic routing
* Requests are forwarded to any available pod

---

## 🧪 Step 7: Verify Load Balancing

Run multiple times:

```bash
curl http://<NodeIP>:30007
```

---

### 📌 Initial Observation

* Same output every time

---

## 🧠 Reason

All pods had identical nginx default page

---

## 🧪 Step 8: Modify Pod Content

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

### 📌 Observation

* Different pods return different responses
* Load balancing becomes visible

---

## 🧪 Step 9: Test Load Balancing Again

```bash
curl http://<NodeIP>:30007
```

---

### 📌 Result

* Responses change randomly
* Traffic distributed across pods

---

## 🧠 Learning

Kubernetes Service:

* Uses kube-proxy
* Implements load balancing
* Works at network level

---

## 🧪 Step 10: Test Self-Healing

Delete a pod:

```bash
kubectl delete pod <pod-name>
```

---

### 📌 Observation

* New pod is automatically created
* Service continues working
* No downtime

---

## 🧠 Learning

Deployment ensures:

* Desired replica count
* Automatic recovery
* High availability

---

## ⚠️ Issues Faced & Fixes

---

### ❌ Unable to Access via Port 80

#### Cause:

* Used ClusterIP instead of NodePort

#### Fix:

```bash
kubectl expose deployment nginx --type=NodePort --port=80
```

---

### ❌ kubectl exec not working

#### Error:

```text
pod does not exist
```

#### Cause:

* Wrong pod name / namespace

#### Fix:

```bash
kubectl get pods
```

---

### ❌ Same Output Every Time

#### Cause:

* All pods identical

#### Fix:

* Modify content inside each pod

---

## 🎯 Outcome

* Application deployed successfully
* Load balancing verified
* Self-healing observed
* Service exposure understood

---

## 📚 Key Learnings

* Deployment manages pods
* Service exposes application
* kube-proxy handles routing
* Kubernetes ensures high availability

---

## � Monitoring & Troubleshooting Commands

This section provides useful kubectl commands for monitoring your nginx deployment and troubleshooting issues.

---

### 📊 Deployment Status

```bash
# Check deployment status and rollout progress
kubectl rollout status deployment/nginx

# View deployment history
kubectl rollout history deployment/nginx

# Get detailed deployment information
kubectl describe deployment nginx
```

---

### 📋 Pod Monitoring

```bash
# Get pods with detailed information
kubectl get pods -o wide

# Watch pods in real-time
kubectl get pods -w

# Get pod resource usage
kubectl top pods

# Describe a specific pod
kubectl describe pod <pod-name>
```

---

### 🌐 Service Monitoring

```bash
# Get service details
kubectl get svc

# Describe service
kubectl describe service nginx

# Check service endpoints
kubectl get endpoints nginx
```

---

### 📝 Logs & Events

```bash
# View logs from a specific pod
kubectl logs <pod-name>

# Follow logs in real-time
kubectl logs -f <pod-name>

# View logs from all pods in deployment
kubectl logs -l app=nginx

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Get events for specific resource
kubectl describe pod <pod-name> | grep -A 20 Events:
```

---

### 📈 Resource Usage

```bash
# Check node resource usage
kubectl top nodes

# Get cluster resource summary
kubectl get nodes --no-headers | awk '{print $1}' | xargs -I {} sh -c 'echo "Node: {}"; kubectl describe node {} | grep -A 10 "Allocated resources"'
```

---

### 🔧 Troubleshooting Commands

```bash
# Check pod status and conditions
kubectl get pods -o jsonpath='{.items[*].status.conditions[*].type}' | tr ' ' '\n' | sort | uniq -c

# Check if pods are ready
kubectl get pods -l app=nginx -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n'

# Test service connectivity from within cluster
kubectl run test-pod --image=busybox --rm -it -- wget -qO- http://nginx:80

# Check network policies (if any)
kubectl get networkpolicies

# Verify kube-proxy status
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

---

### ℹ️ Cluster Information

```bash
# Get cluster info
kubectl cluster-info

# Check API server status
kubectl get componentstatuses

# Get API resources
kubectl api-resources

# Check version
kubectl version --short
```
---

# 99 - Common Issues & Troubleshooting (Real Scenarios)

This document captures real issues faced during Kubernetes setup and usage, along with root cause analysis and fixes.

---

# ❌ Issue 1: Unable to Exec into Pod

---

## 🔴 Error Observed

```text
error: unable to upgrade connection: pod does not exist
```

---

## 📌 Situation

* Pod visible in:

```bash
kubectl get pods -o wide
```

* Pod status = Running
* Still unable to:

  * exec into pod
  * fetch logs

---

## 🧠 Root Causes

---

### 1. Wrong Shell Used

Some containers (like nginx) do not include `/bin/bash`

#### ❌ Fails:

```bash
kubectl exec -it <pod-name> -- /bin/bash
```

#### ✅ Works:

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

---

### 2. Pod Name Changed (ReplicaSet Behavior)

* Pods are dynamic
* Deleted/recreated automatically

#### Fix:

```bash
kubectl get pods
```

Use latest pod name

---

### 3. API Server Instability

Symptoms:

* `kubectl get pods` works
* `exec` / `logs` fail

#### Fix:

```bash
sudo systemctl restart kubelet
sudo systemctl restart containerd
```

---

### 4. Network (CNI) Delay

* Calico not fully initialized
* Temporary connectivity issues

---

## 🧪 Debug Commands

```bash
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

---

## 🎯 Outcome

* Successfully accessed container shell
* Modified nginx content
* Verified load balancing

---

## 📚 Key Learning

* Not all containers have bash
* Always verify pod name
* Kubernetes recreates pods dynamically
* Control-plane issues affect exec/logs

---

# ❌ Issue 2: NodePort Not Accessible (Wrong Node IP)

---

## 🔴 Problem

* Service created successfully
* Pods running
* Application not accessible from browser

---

## 🧠 Root Cause

In Vagrant setup:

* Each VM has multiple network interfaces:

  * NAT (internet)
  * Private network (192.168.56.x)

Kubernetes may pick wrong IP (NAT IP)

---

## 🔍 Verify

```bash
kubectl get nodes -o wide
```

Check:

```text
INTERNAL-IP
```

---

## ⚠️ Problem Scenario

* NodePort exists
* Curl fails using incorrect IP
* Service works internally but not externally

---

## ✅ Fix (Simple)

Use correct Vagrant private IP:

```bash
curl http://192.168.56.10:<NodePort>
```

---

## 🔧 Fix (Advanced - Force Node IP)

```bash
sudo nano /etc/default/kubelet
```

Add:

```bash
KUBELET_EXTRA_ARGS=--node-ip=192.168.56.10
```

Restart:

```bash
sudo systemctl daemon-reexec
sudo systemctl restart kubelet
```

---

## 📚 Key Learning

* Kubernetes auto-detects node IP
* Multiple NICs can cause wrong selection
* NodePort depends on correct node IP

---

# 🧠 Final Takeaways

* Real-world Kubernetes = debugging + understanding
* Many issues are environment-related (VMs, networking)
* Observability (logs, describe, status) is key

---

## �🔜 Next Step

Deep dive into:

* kube-proxy
* iptables rules
* how traffic is actually routed    