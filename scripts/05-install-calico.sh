#!/bin/bash

set -e

# ============================================================
# Kubernetes Calico CNI Installation
# ============================================================
#
# Purpose:
#   Install and verify Calico networking.
#
# Features:
#   - Waits for Kubernetes API
#   - Handles temporary API unavailability
#   - Idempotent
#   - Does not reinstall Calico unnecessarily
#   - Waits for Calico components
#   - Verifies node networking
#
# ============================================================

echo "=================================================="
echo " Kubernetes Calico Installation"
echo "=================================================="


# ============================================================
# Configuration
# ============================================================

CALICO_VERSION="v3.32.1"

CALICO_MANIFEST="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

MAX_RETRIES=60
RETRY_INTERVAL=5


# ============================================================
# Check kubectl
# ============================================================

if ! command -v kubectl >/dev/null 2>&1; then
    echo "[ERROR] kubectl is not installed."
    exit 1
fi


# ============================================================
# Check kubeconfig
# ============================================================

if [ ! -f "$HOME/.kube/config" ]; then
    echo "[INFO] kubeconfig not found."
    if [ -f /etc/kubernetes/admin.conf ]; then
        echo "[INFO] Configuring kubeconfig..."
        mkdir -p "$HOME/.kube"
        sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
        sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
    else
        echo "[ERROR] /etc/kubernetes/admin.conf not found."
        exit 1
    fi
fi


# ============================================================
# Wait for Kubernetes API
# ============================================================

echo "[INFO] Waiting for Kubernetes API..."
API_READY=false
for ((i=1; i<=MAX_RETRIES; i++)); do
    if kubectl get --raw='/readyz' >/dev/null 2>&1; then
        echo "[INFO] Kubernetes API is ready."
        API_READY=true
        break
    fi
    echo "[WAIT] Kubernetes API not ready yet... attempt ${i}/${MAX_RETRIES}"
    sleep "$RETRY_INTERVAL"
done


if [ "$API_READY" = false ]; then
    echo "[ERROR] Kubernetes API did not become ready."
    echo
    echo "[INFO] Checking kubelet status..."
    sudo systemctl status kubelet --no-pager || true
    echo
    echo "[INFO] Checking Kubernetes nodes..."
    kubectl get nodes || true
    exit 1

fi


# ============================================================
# Verify Kubernetes node
# ============================================================

echo
echo "[INFO] Kubernetes nodes:"

kubectl get nodes -o wide

# ============================================================
# Check whether Calico is already installed
# ============================================================

echo
echo "[INFO] Checking existing Calico installation..."

if kubectl get daemonset calico-node -n kube-system >/dev/null 2>&1; then

    echo "[INFO] Calico already exists."
else
    echo "[INFO] Calico is not installed."
    echo "[INFO] Installing Calico ${CALICO_VERSION}..."
    kubectl apply -f "$CALICO_MANIFEST"
fi


# ============================================================
# Wait for Calico DaemonSet
# ============================================================

echo
echo "[INFO] Waiting for Calico DaemonSet..."

CALICO_READY=false

for ((i=1; i<=MAX_RETRIES; i++)); do
    DESIRED=$(kubectl get daemonset calico-node \
        -n kube-system \
        -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
    READY=$(kubectl get daemonset calico-node \
        -n kube-system \
        -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    echo "[WAIT] Calico: ${READY}/${DESIRED} nodes ready... attempt ${i}/${MAX_RETRIES}"

    if [ "$DESIRED" != "0" ] && [ "$READY" = "$DESIRED" ]; then
        echo "[INFO] Calico DaemonSet is ready."
        CALICO_READY=true
        break
    fi
    sleep "$RETRY_INTERVAL"
done


# ============================================================
# Calico verification
# ============================================================

if [ "$CALICO_READY" = false ]; then
    echo
    echo "[ERROR] Calico did not become ready."
    echo
    echo "[INFO] Calico DaemonSet:"
    kubectl get daemonset calico-node \
        -n kube-system \
        -o wide || true
    echo
    echo "[INFO] Calico Pods:"
    kubectl get pods \
        -n kube-system \
        -l k8s-app=calico-node \
        -o wide || true
    echo
    echo "[INFO] Recent Calico events:"
    kubectl get events \
        -n kube-system \
        --sort-by='.lastTimestamp' \
        | tail -30 || true
    exit 1
fi


# ============================================================
# Wait for CoreDNS
# ============================================================

echo
echo "[INFO] Waiting for CoreDNS..."

if kubectl wait \
    --namespace kube-system \
    --for=condition=Ready \
    pod \
    -l k8s-app=kube-dns \
    --timeout=300s; then
    echo "[INFO] CoreDNS is ready."
else
    echo "[WARNING] CoreDNS did not become ready within timeout."
fi


# ============================================================
# Final Verification
# ============================================================

echo
echo "=================================================="
echo " Kubernetes Networking Status"
echo "=================================================="

echo
echo "[INFO] Nodes:"
kubectl get nodes -o wide

echo
echo "[INFO] Calico:"
kubectl get pods \
    -n kube-system \
    -l k8s-app=calico-node \
    -o wide
echo
echo "[INFO] CoreDNS:"
kubectl get pods \
    -n kube-system \
    -l k8s-app=kube-dns \
    -o wide
echo
echo "=================================================="
echo " Calico installation completed successfully"
echo "=================================================="