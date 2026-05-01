# Kubernetes Vagrant Lab 🚀

This repository documents my hands-on learning and implementation of Kubernetes using Vagrant and VirtualBox.

---

## 📌 Topics Covered

1. Environment Setup (Windows + Vagrant + VirtualBox)
2. Creating Multi-Node Cluster
3. kubeadm Initialization
4. Installing Container Runtime (containerd)
5. Pod Networking (Calico)
6. Understanding kube-proxy & iptables
7. Deployments & ReplicaSets
8. Services (NodePort)
9. YAML Deep Dive
10. ConfigMaps
11. Secrets
---

## 📂 File Structure
```
kubernetes-vagrant-lab/
│
├── README.md
├── docs/
│   ├── 01-setup.md
│   ├── 02-cluster-creation.md
│   ├── 03-node-setup.md
│   ├── 04-networking.md
│   ├── 05-services.md
│   ├── 06-kube-proxy-iptables.md
│   ├── 07-deployments.md
│   ├── 08-yaml-basics.md
│   ├── 09-configmap.md
│   └── 10-secrets.md
│
├── manifests/
│   ├── nginx-deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── secret.yaml
│
└── scripts/
    └── (future automation scripts)
```

## 📂 Structure

- `/docs` → Learning notes
- `/manifests` → Kubernetes YAML files
- `/scripts` → Automation scripts (coming soon)

---

## 🎯 Goal

To build strong Kubernetes & DevOps fundamentals through practical implementation.
