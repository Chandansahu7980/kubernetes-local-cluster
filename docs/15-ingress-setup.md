# NGINX Ingress Controller Installation and Setup

## Overview

This guide installs the NGINX Ingress Controller on a Kubernetes cluster and exposes an application using an Ingress resource.

The goal is to access the app using a hostname instead of a NodePort.

- Before: `http://192.168.56.10:30080`
- After: `http://crud.local`

---

## Architecture

```text
Browser
   |
crud.local
   |
Ingress Controller
   |
php-service
   |
PHP Pods
```

The Ingress Controller acts as a reverse proxy and routes incoming requests to the correct Kubernetes Service.

---

## Prerequisites

Ensure the following are already set up:

- Kubernetes cluster created with `kubeadm`
- Calico CNI installed
- `kubectl` configured
- Application deployed and reachable
- Service exposing the application exists

Verify cluster health:

```bash
kubectl get nodes
kubectl get pods -A
```

All nodes and pods should be healthy.

---

## Step 1: Install the NGINX Ingress Controller

For bare-metal or Vagrant-based Kubernetes clusters:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
```

---

## Step 2: Verify Installation

### Check namespace

```bash
kubectl get ns
```

Confirm that `ingress-nginx` is present.

### Check pods

```bash
kubectl get pods -n ingress-nginx
```

Expected output contains:

- `ingress-nginx-controller-...` → `1/1 Running`
- `ingress-nginx-admission-create-...` → `0/1 Completed`
- `ingress-nginx-admission-patch-...` → `0/1 Completed`

### Check deployment

```bash
kubectl get deployment -n ingress-nginx
```

Expected output contains:

- `ingress-nginx-controller` → `1/1`

### Check service

```bash
kubectl get svc -n ingress-nginx
```

Expected output includes a NodePort service such as:

- `ingress-nginx-controller` → `80:31234/TCP,443:31443/TCP`

---

## Step 3: Inspect Controller Logs

```bash
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

Look for:

- `Starting NGINX Ingress controller`

This confirms the controller is active and watching resources.

---

## Step 4: Inspect Created Resources

```bash
kubectl get all -n ingress-nginx
```

You should see:

- Deployment
- ReplicaSet
- Pods
- Services
- Jobs

This confirms the Ingress Controller is deployed successfully.

---

## Step 5: Understand the Controller Service

```bash
kubectl get svc -n ingress-nginx
```

A typical result looks like:

- `ingress-nginx-controller` → `NodePort` → `80:31234/TCP,443:31443/TCP`

### What this means

| Port | Purpose |
|------|---------|
| `80` | HTTP traffic |
| `443` | HTTPS traffic |
| NodePort | External access on each node |

Traffic enters the cluster through this service.

---

## Step 6: Verify the Application Service

Confirm the service that backs your app:

```bash
kubectl get svc -n pro2
```

Example output:

- `php-service` → `NodePort` → `80:30080/TCP`

Verify endpoints:

```bash
kubectl get endpoints php-service -n pro2
```

Example output:

- `php-service` → `10.244.1.5:80`

Ensure the application is reachable before creating an Ingress.

---

## Step 7: Create the Ingress Resource

Create a file named `php-ingress.yaml` with the following content:

```yaml
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

Apply the manifest:

```bash
kubectl apply -f php-ingress.yaml
```

---

## Step 8: Verify the Ingress Resource

```bash
kubectl get ingress -n pro2
```

Expected output:

- `php-ingress` → `nginx` → `crud.local`

Describe the Ingress:

```bash
kubectl describe ingress php-ingress -n pro2
```

Verify:

- Host: `crud.local`
- Backend service: `php-service:80`

---

## Step 9: Configure Local DNS Resolution

On Windows, open:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add this entry:

```text
192.168.56.10 crud.local
```

Replace the IP address with your Kubernetes node IP if different.

Save the file, then verify:

```bash
ping crud.local
```

Expected output:

- `Pinging crud.local [192.168.56.10]`

---

## Step 10: Determine the Ingress Controller Port

```bash
kubectl get svc -n ingress-nginx
```

A sample output shows:

- `ingress-nginx-controller` → `NodePort` → `80:31234/TCP`

In this example, the NodePort is `31234`.

---

## Step 11: Access the Application Through Ingress

Open your browser and visit:

```text
http://crud.local:31234
```

The app should load through the Ingress Controller.

---

## Verification Commands

```bash
kubectl get ingress -A
kubectl get svc -A
kubectl get endpoints -A
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

---

## Troubleshooting

### Ingress not created

```bash
kubectl get ingress -A
kubectl describe ingress <ingress-name>
```

Check for YAML syntax issues or missing backend services.

### Controller not running

```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

### Service has no endpoints

```bash
kubectl get endpoints <service-name>
```

If no endpoints exist, check:

- Pod labels
- Service selector

### Hostname not resolving

Verify the hosts file entry:

```text
192.168.56.10 crud.local
```

Then test again:

```bash
ping crud.local
```

### Application returns 404

```bash
kubectl describe ingress php-ingress -n pro2
```

Verify:

- Hostname is correct
- Service name matches
- Service port is correct


Verify hosts file:

192.168.56.10 crud.local

Test:

ping crud.local
Application Returns 404

Verify:

kubectl describe ingress php-ingress -n pro2

Check:

Hostname
Service name
Service port