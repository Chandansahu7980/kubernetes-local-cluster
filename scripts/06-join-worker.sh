#!/bin/bash

set -e

# ============================================================
# Kubernetes Worker Node Join
# ============================================================
#
# Purpose:
#   Join this worker node to the Kubernetes control plane.
#
# Features:
#   - Idempotent
#   - Waits for join command
#   - Validates master connectivity
#   - Executes kubeadm join
#   - Verifies node configuration
#
# ============================================================

echo "=================================================="
echo " Kubernetes Worker Node Join"
echo "=================================================="

# ============================================================
# Configuration
# ============================================================

JOIN_FILE="/vagrant/data/join-command.sh"

MASTER_IP="192.168.56.10"
API_PORT="6443"

MAX_RETRIES=60
RETRY_INTERVAL=5

# ============================================================
# Identify Worker
# ============================================================

WORKER_NAME=$(hostname)

echo "[INFO] Worker: $WORKER_NAME"

# ============================================================
# Check if Worker Already Joined
# ============================================================
#
# /etc/kubernetes/kubelet.conf is created when kubeadm join
# successfully configures the worker.
#
# If this exists, we don't run kubeadm join again.
# ============================================================

if [ -f "/etc/kubernetes/kubelet.conf" ]; then
    echo "[INFO] Worker is already configured."
    echo "[INFO] Skipping kubeadm join."
    exit 0
fi

# ============================================================
# Wait for Shared Join Command
# ============================================================

echo "[INFO] Waiting for join command..."
JOIN_FILE_READY=false
for ((i=1; i<=MAX_RETRIES; i++)); do
    if [ -s "$JOIN_FILE" ]; then
        echo "[INFO] Join command found."
        JOIN_FILE_READY=true
        break
    fi
    echo "[WAIT] Join command not available... attempt ${i}/${MAX_RETRIES}"
    sleep "$RETRY_INTERVAL"
done


if [ "$JOIN_FILE_READY" = false ]; then
    echo "[ERROR] Join command was not found."
    echo "[ERROR] Expected file:"
    echo "        $JOIN_FILE"
    exit 1
fi


# ============================================================
# Verify Master API Connectivity
# ============================================================

echo "[INFO] Checking Kubernetes API connectivity..."
API_READY=false
for ((i=1; i<=MAX_RETRIES; i++)); do
    if timeout 5 bash -c \
        "</dev/tcp/${MASTER_IP}/${API_PORT}" \
        >/dev/null 2>&1; then
        echo "[INFO] Kubernetes API is reachable."
        API_READY=true
        break
    fi
    echo "[WAIT] Master API not reachable... attempt ${i}/${MAX_RETRIES}"
    sleep "$RETRY_INTERVAL"
done


if [ "$API_READY" = false ]; then
    echo "[ERROR] Cannot reach Kubernetes API."
    echo "[ERROR] Master: ${MASTER_IP}:${API_PORT}"
    exit 1
fi


# ============================================================
# Display Join Command
# ============================================================

echo
echo "[INFO] Join command:"
cat "$JOIN_FILE"
# ============================================================
# Execute kubeadm join
# ============================================================
echo
echo "[INFO] Joining Kubernetes cluster..."
sudo bash "$JOIN_FILE"

# ============================================================
# Verify kubelet
# ============================================================

echo
echo "[INFO] Checking kubelet..."

if systemctl is-active --quiet kubelet; then
    echo "[INFO] kubelet is running."
else
    echo "[WARNING] kubelet is not currently active."
    sudo systemctl status kubelet --no-pager || true
fi

# ============================================================
# Verify Worker Configuration
# ============================================================

if [ -f "/etc/kubernetes/kubelet.conf" ]; then
    echo
    echo "=================================================="
    echo " Worker Successfully Joined"
    echo "=================================================="
    echo "[INFO] Worker: $WORKER_NAME"
else
    echo
    echo "[ERROR] kubeadm join completed but kubelet.conf"
    echo "        was not found."
    exit 1
fi

echo
echo "=================================================="
echo " Worker Join Completed"
echo "=================================================="