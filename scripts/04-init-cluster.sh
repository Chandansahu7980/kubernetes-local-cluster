#!/bin/bash

set -e

# ============================================================
# Kubernetes Control Plane Initialization
# ============================================================
#
# Purpose:
#   Initialize Kubernetes control plane and generate the
#   worker join command.
#
# Features:
#   - Automatically detects master IP
#   - Idempotent kubeadm initialization
#   - Configures kubectl
#   - Generates fresh worker join command
#   - Stores join command in shared /vagrant/data directory
# ============================================================

echo "=================================================="
echo " Kubernetes Control Plane Initialization"
echo "=================================================="

# ============================================================
# Configuration
# ============================================================

KUBECONFIG="$HOME/.kube/config"
JOIN_FILE="/vagrant/data/join-command.sh"

# ============================================================
# Detect Master IP
# ============================================================

MASTER_IP=$(ip -4 addr show | \
    awk '/inet 192\.168\.56\./ {
        sub("/.*", "", $2);
        print $2
    }' | head -n1)


if [ -z "$MASTER_IP" ]; then
    echo "[ERROR] Could not detect master IP."
    echo
    echo "[INFO] Available IPv4 addresses:"
    ip -4 addr
    exit 1
fi

echo "[INFO] Master IP: $MASTER_IP"

# ============================================================
# Initialize Kubernetes Control Plane
# ============================================================

if [ -f "/etc/kubernetes/admin.conf" ]; then
    echo "[INFO] Kubernetes control plane already initialized."
    echo "[INFO] Skipping kubeadm init."
else
    echo "[INFO] Initializing Kubernetes control plane..."
    sudo kubeadm init \
        --apiserver-advertise-address="$MASTER_IP" \
        --pod-network-cidr=192.168.0.0/16
fi


# ============================================================
# Configure kubectl
# ============================================================

echo "[INFO] Configuring kubectl..."

mkdir -p "$HOME/.kube"

if [ ! -f "$KUBECONFIG" ]; then
    sudo cp /etc/kubernetes/admin.conf "$KUBECONFIG"
    sudo chown "$(id -u):$(id -g)" "$KUBECONFIG"
else
    echo "[INFO] kubectl configuration already exists."
fi

# ============================================================
# Wait for Kubernetes API
# ============================================================

echo "[INFO] Waiting for Kubernetes API..."

MAX_RETRIES=60
RETRY_INTERVAL=5

API_READY=false

for ((i=1; i<=MAX_RETRIES; i++)); do
    if kubectl get --raw='/readyz' >/dev/null 2>&1; then
        echo "[INFO] Kubernetes API is ready."
        API_READY=true
        break
    fi

    echo "[WAIT] Kubernetes API not ready... attempt ${i}/${MAX_RETRIES}"
    sleep "$RETRY_INTERVAL"

done


if [ "$API_READY" = false ]; then
    echo "[ERROR] Kubernetes API did not become ready."
    sudo systemctl status kubelet --no-pager || true
    exit 1
fi


# ============================================================
# Generate Worker Join Command
# ============================================================
#
# IMPORTANT:
#
# We generate a fresh token every time this script runs.
#
# This avoids depending on an old kubeadm token.
#
# The resulting command will look like:
#
# kubeadm join 192.168.56.10:6443 \
#   --token xxxxxx.xxxxxxxxxxxxxx \
#   --discovery-token-ca-cert-hash sha256:xxxx
#
# ============================================================

echo "[INFO] Generating worker join command..."
JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)
if [ -z "$JOIN_COMMAND" ]; then
    echo "[ERROR] Failed to generate kubeadm join command."
    exit 1
fi

# ============================================================
# Verify Shared Directory
# ============================================================

if [ ! -d "/vagrant/data" ]; then
    echo "[ERROR] Shared directory /vagrant/data does not exist."
    echo "[INFO] Check Vagrantfile synced folder configuration."
    exit 1
fi


# ============================================================
# Save Join Command
# ============================================================
echo "[INFO] Saving worker join command..."
sudo tee "$JOIN_FILE" > /dev/null <<EOF
#!/bin/bash
$JOIN_COMMAND
EOF

sudo chmod 755 "$JOIN_FILE"

# ============================================================
# Verify Join Command
# ============================================================

if [ ! -s "$JOIN_FILE" ]; then
    echo "[ERROR] Join command file was not created correctly."
    exit 1
fi


# ============================================================
# Display Cluster Information
# ============================================================

echo
echo "=================================================="
echo " Kubernetes Control Plane Ready"
echo "=================================================="
echo
echo "[INFO] Master:"
kubectl get node master -o wide
echo
echo "[INFO] Join command generated:"
echo "$JOIN_FILE"
echo
echo "[INFO] Join command:"
cat "$JOIN_FILE"
echo
echo "=================================================="
echo " Control Plane Initialization Completed"
echo "=================================================="