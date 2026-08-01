#!/bin/bash

set -e

NODE_NAME="$1"

echo "=================================================="
echo " Master Node Preparation"
echo "=================================================="


# --------------------------------------------------
# 1. Verify hostname
# --------------------------------------------------

if [ "${NODE_NAME}" != "master" ]; then
    echo "[ERROR] This script should only run on master."
    exit 1
fi


# --------------------------------------------------
# 2. Detect Host-Only Network IP
# --------------------------------------------------

echo "[INFO] Detecting Kubernetes node IP..."

NODE_IP=$(ip -4 addr show | \
    awk '/inet 192\.168\.56\./ {print $2}' | \
    cut -d/ -f1 | \
    head -n1)

if [ -z "${NODE_IP}" ]; then
    echo "[ERROR] Could not detect 192.168.56.x address."
    echo "[ERROR] Check the Vagrant host-only network."
    exit 1
fi

echo "[OK] Detected node IP: ${NODE_IP}"


# --------------------------------------------------
# 3. Verify containerd
# --------------------------------------------------

echo "[INFO] Checking containerd..."

if systemctl is-active --quiet containerd; then
    echo "[OK] containerd is running."
else
    echo "[ERROR] containerd is not running."
    exit 1
fi


# --------------------------------------------------
# 4. Verify kubeadm
# --------------------------------------------------

echo "[INFO] Checking kubeadm..."

if command -v kubeadm >/dev/null 2>&1; then
    echo "[OK] kubeadm is installed."
    kubeadm version -o short
else
    echo "[ERROR] kubeadm is not installed."
    exit 1
fi


# --------------------------------------------------
# 5. Verify kubelet
# --------------------------------------------------

echo "[INFO] Checking kubelet..."

if command -v kubelet >/dev/null 2>&1; then
    echo "[OK] kubelet is installed."
    kubelet --version
else
    echo "[ERROR] kubelet is not installed."
    exit 1
fi


# --------------------------------------------------
# 6. Verify kubectl
# --------------------------------------------------

echo "[INFO] Checking kubectl..."

if command -v kubectl >/dev/null 2>&1; then
    echo "[OK] kubectl is installed."
else
    echo "[ERROR] kubectl is not installed."
    exit 1
fi


# --------------------------------------------------
# 7. Configure kubelet Node IP
# --------------------------------------------------

echo "[INFO] Configuring kubelet node IP..."

cat > /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}
EOF

systemctl daemon-reload
systemctl restart kubelet


# --------------------------------------------------
# 8. Prepare Kubernetes Directory
# --------------------------------------------------

mkdir -p /etc/kubernetes


# --------------------------------------------------
# 9. Display Information
# --------------------------------------------------

echo ""
echo "=================================================="
echo " Master Node Preparation Completed"
echo "=================================================="

echo "Hostname:"
hostname

echo ""
echo "Detected Kubernetes IP:"
echo "${NODE_IP}"

echo ""
echo "Host-only addresses:"
ip -4 addr show | grep '192.168.56.' || true

echo ""
echo "Kubernetes version:"
kubeadm version -o short

echo ""
echo "=================================================="