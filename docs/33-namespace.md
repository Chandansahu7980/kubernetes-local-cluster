# Kubernetes Namespaces

Namespaces provide logical isolation for Kubernetes resources within the same cluster. They help organize workloads, separate environments, and apply policies such as RBAC and ResourceQuota without creating multiple Kubernetes clusters.

---

# Why Namespaces?

Without namespaces, all resources are created in the **default** namespace, making resource management difficult as the cluster grows.

Namespaces help you:

- Organize applications
- Separate environments (Dev, QA, Production)
- Isolate teams
- Apply RBAC permissions
- Apply ResourceQuota and LimitRange
- Avoid resource name conflicts

---

# Kubernetes Default Namespaces

Check existing namespaces:

```bash
kubectl get namespaces
```

Example:

```text
NAME              STATUS   AGE
default           Active   10d
kube-system       Active   10d
kube-public       Active   10d
kube-node-lease   Active   10d
```

### default

Default namespace where resources are created if no namespace is specified.

### kube-system

Contains Kubernetes control plane components and networking components.

Examples:

- kube-apiserver
- etcd
- CoreDNS
- kube-proxy
- Calico

### kube-public

Contains publicly accessible resources.

### kube-node-lease

Stores node heartbeat information to improve cluster scalability.

---

# Create a Namespace

```bash
kubectl create namespace dev
```

Verify:

```bash
kubectl get namespaces
```

---

# Create Namespace Using YAML

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
```

Apply:

```bash
kubectl apply -f namespace.yaml
```

---

# Deploy Resources Inside a Namespace

Example:

```bash
kubectl run nginx \
--image=nginx \
-n development
```

Verify:

```bash
kubectl get pods -n development
```

---

# Deploy Using YAML

```yaml
metadata:
  name: nginx
  namespace: development
```

---

# View Resources from a Namespace

Pods

```bash
kubectl get pods -n development
```

Services

```bash
kubectl get svc -n development
```

Deployments

```bash
kubectl get deployments -n development
```

Everything

```bash
kubectl get all -n development
```

---

# View Resources Across All Namespaces

```bash
kubectl get pods -A
```

or

```bash
kubectl get pods --all-namespaces
```

---

# Change Current Namespace

Instead of typing `-n` every time:

```bash
kubectl config set-context --current --namespace=development
```

Check:

```bash
kubectl config view --minify | grep namespace
```

Return to default:

```bash
kubectl config set-context --current --namespace=default
```

---

# Delete Namespace

```bash
kubectl delete namespace development
```

Deleting a namespace also deletes all resources inside it.

---

# Practice Lab

## Step 1

Create a namespace.

```bash
kubectl create namespace team-a
```

---

## Step 2

Deploy nginx.

```bash
kubectl run nginx \
--image=nginx \
-n team-a
```

---

## Step 3

Verify.

```bash
kubectl get pods -n team-a
```

---

## Step 4

Deploy another pod in the default namespace.

```bash
kubectl run nginx-default \
--image=nginx
```

Verify:

```bash
kubectl get pods -A
```

Expected:

```text
NAMESPACE     NAME
default       nginx-default
team-a        nginx
```

This demonstrates that two resources with similar purposes can exist independently because they belong to different namespaces.

---

# Where Namespaces Are Used

Development

```text
dev
```

Testing

```text
qa
```

Production

```text
prod
```

Monitoring

```text
monitoring
```

Logging

```text
logging
```

Ingress

```text
ingress-nginx
```

Each team or application can have its own namespace for better organization and isolation.

---

# Important Notes

Namespaces:

- Do not consume CPU or Memory by themselves.
- Are logical isolation only.
- Do not create a new Kubernetes cluster.
- Are lightweight and easy to create.
- Can contain Pods, Services, Deployments, Secrets, ConfigMaps, PVCs, Jobs, and more.

---

# Namespace vs Cluster

| Cluster | Namespace |
|----------|-----------|
| Physical/Logical Kubernetes environment | Logical partition inside a cluster |
| Runs Kubernetes control plane | Organizes resources |
| Expensive to create | Lightweight |
| Completely isolated | Shares cluster resources |

---

# Common Commands

Create namespace

```bash
kubectl create namespace demo
```

List namespaces

```bash
kubectl get ns
```

Deploy in namespace

```bash
kubectl apply -f deployment.yaml -n demo
```

View all resources

```bash
kubectl get all -n demo
```

View all namespaces

```bash
kubectl get ns
```

Delete namespace

```bash
kubectl delete ns demo
```

---

# Common Mistakes

### Pod not found

```text
Error from server (NotFound)
```

Cause:

Looking in the wrong namespace.

Fix:

```bash
kubectl get pods -A
```

or

```bash
kubectl get pods -n <namespace>
```

---

### Resource created in default namespace

Cause:

Forgot to specify namespace.

Fix:

```bash
kubectl apply -f deployment.yaml -n development
```

or include:

```yaml
metadata:
  namespace: development
```

---

### Deleting a Namespace

Deleting a namespace deletes **all resources** inside it.

Always verify before deleting:

```bash
kubectl get all -n <namespace>
```

---

# Key Learnings

- Namespace is a logical isolation mechanism inside a Kubernetes cluster.
- Namespaces help organize applications and teams.
- They do not consume CPU or Memory by themselves.
- Resources inside one namespace are isolated from resources in another namespace.
- Namespaces are commonly used with RBAC, ResourceQuota, and LimitRange.
- A single Kubernetes cluster can host multiple applications using different namespaces.
