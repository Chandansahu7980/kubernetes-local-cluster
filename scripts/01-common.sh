#!/bin/bash

set -e

NODE_NAME="$1"
NODE_ROLE="$2"

echo "=================================================="
echo " Kubernetes Common Node Provisioning"
echo "=================================================="
echo "Node : ${NODE_NAME}"
echo "Role : ${NODE_ROLE}"
echo "=================================================="


# --------------------------------------------------
# 1. Validate arguments
# --------------------------------------------------

if [ -z "${NODE_NAME}" ] || [ -z "${NODE_ROLE}" ]; then
    echo "[ERROR] Usage: $0 <node-name> <node-role>"
    exit 1
fi


# --------------------------------------------------
# 2. Update package information
# --------------------------------------------------

echo "[1/10] Updating package information..."

apt-get update


# --------------------------------------------------
# 3. Disable Swap
# --------------------------------------------------

echo "[2/10] Disabling swap..."

swapoff -a

# Disable swap permanently
sed -i '/ swap / s/^/#/' /etc/fstab


# --------------------------------------------------
# 4. Load Required Kernel Modules
# --------------------------------------------------

echo "[3/10] Loading kernel modules..."

cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter


# --------------------------------------------------
# 5. Configure Kubernetes Networking
# --------------------------------------------------

echo "[4/10] Configuring Kubernetes networking..."

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system


# --------------------------------------------------
# 6. Install Required Packages
# --------------------------------------------------

echo "[5/10] Installing required packages..."

apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg \
    software-properties-common \
    conntrack \
    socat


# --------------------------------------------------
# 7. Install and Configure containerd
# --------------------------------------------------

echo "[6/10] Installing containerd..."

apt-get install -y containerd

echo "[7/10] Configuring containerd..."

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

# Kubernetes uses systemd as the cgroup driver
sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd


# --------------------------------------------------
# 8. Configure Kubernetes Repository
# --------------------------------------------------

echo "[8/10] Configuring Kubernetes repository..."

mkdir -p /etc/apt/keyrings

curl -fsSL \
    https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key \
    | gpg --dearmor --batch --yes \
    -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /
EOF

apt-get update


# --------------------------------------------------
# 9. Install Kubernetes Components
# --------------------------------------------------

echo "[9/10] Installing Kubernetes components..."

apt-get install -y \
    kubelet=1.28.15-1.1 \
    kubeadm=1.28.15-1.1 \
    kubectl=1.28.15-1.1

apt-mark hold kubelet kubeadm kubectl


# --------------------------------------------------
# 10. Enable kubelet
# --------------------------------------------------

echo "[10/10] Enabling kubelet..."

systemctl enable kubelet


# --------------------------------------------------
# Final Verification
# --------------------------------------------------

echo ""
echo "=================================================="
echo " Common Provisioning Completed Successfully"
echo "=================================================="

echo "Node:"
hostname

echo ""
echo "Container runtime:"
systemctl is-active containerd

echo ""
echo "Kubernetes versions:"
kubeadm version -o short
kubectl version --client=true 2>/dev/null || true

echo ""
echo "Swap:"
free -h

echo ""
echo "=================================================="