#!/bin/bash

set -euo pipefail

# ============================================================
# Kubernetes Calico CNI Installation
# ============================================================
#
# Purpose:
#   Install and verify Calico networking for the Kubernetes
#   lab cluster.
#
# Kubernetes:
#   v1.28.15
#
# Calico:
#   v3.26.4
#
# Network:
#   Host-only network: 192.168.56.0/24
#   Interface: enp0s8
#
# Features:
#   - Verifies kubectl
#   - Verifies kubeconfig
#   - Waits for Kubernetes API
#   - Verifies Kubernetes node
#   - Checks existing Calico installation
#   - Detects incomplete/failed Calico installation
#   - Cleans failed Calico installation when required
#   - Downloads the Calico manifest
#   - Forces Calico to use the host-only interface
#   - Installs Calico
#   - Waits for Calico DaemonSet
#   - Waits for Calico controller
#   - Waits for CoreDNS
#   - Performs final networking verification
#
# ============================================================

echo "=================================================="
echo " Kubernetes Calico CNI Installation"
echo "=================================================="

# ============================================================
# Configuration
# ============================================================

CALICO_VERSION="v3.26.4"

CALICO_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

CALICO_MANIFEST="/tmp/calico-${CALICO_VERSION}.yaml"

KUBE_SYSTEM_NAMESPACE="kube-system"

CALICO_INTERFACE="enp0s8"

MAX_RETRIES=60
RETRY_INTERVAL=5

EXPECTED_NODE_IP="192.168.56.10"

# ============================================================
# Helper Functions
# ============================================================

log_info() {
    echo "[INFO] $1"
}

log_ok() {
    echo "[OK] $1"
}

log_warn() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1"
}


# ============================================================
# 1. Verify kubectl
# ============================================================

echo
echo "=================================================="
echo " [1/10] Checking kubectl"
echo "=================================================="

if ! command -v kubectl >/dev/null 2>&1; then
    log_error "kubectl is not installed."
    exit 1
fi

log_ok "kubectl is installed."

kubectl version --client=true || true


# ============================================================
# 2. Configure kubeconfig
# ============================================================

echo
echo "=================================================="
echo " [2/10] Configuring kubeconfig"
echo "=================================================="

# ------------------------------------------------------------
# Configure kubeconfig for root
# ------------------------------------------------------------

log_info "Configuring kubeconfig for root..."

if [ ! -f /etc/kubernetes/admin.conf ]; then
    log_error "/etc/kubernetes/admin.conf not found."
    log_error "Is kubeadm init completed?"
    exit 1
fi

mkdir -p /root/.kube

cp -f /etc/kubernetes/admin.conf /root/.kube/config

chown root:root /root/.kube/config
chmod 600 /root/.kube/config

log_ok "Root kubeconfig configured."


# ------------------------------------------------------------
# Configure kubeconfig for vagrant
# ------------------------------------------------------------

log_info "Configuring kubeconfig for vagrant..."

if id vagrant >/dev/null 2>&1; then
    mkdir -p /home/vagrant/.kube
    cp -f /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    chown vagrant:vagrant /home/vagrant/.kube/config
    chmod 600 /home/vagrant/.kube/config
    log_ok "Vagrant kubeconfig configured."
else
    log_warn "User 'vagrant' does not exist."
    log_warn "Skipping vagrant kubeconfig."
fi

# ------------------------------------------------------------
# Verify root kubeconfig
# ------------------------------------------------------------

log_info "Verifying kubectl access as root..."
export KUBECONFIG=/root/.kube/config
if kubectl get nodes >/dev/null 2>&1; then
    log_ok "Root kubectl access verified."
else
    log_warn "Root kubectl access could not be verified yet."
fi


# ------------------------------------------------------------
# Verify vagrant kubeconfig
# ------------------------------------------------------------

if id vagrant >/dev/null 2>&1; then
    log_info "Verifying kubectl access as vagrant..."
    if sudo -u vagrant \
        KUBECONFIG=/home/vagrant/.kube/config \
        kubectl get nodes >/dev/null 2>&1; then
        log_ok "Vagrant kubectl access verified."
    else
        log_warn "Vagrant kubectl access could not be verified yet."
    fi
fi

# ============================================================
# 3. Wait for Kubernetes API
# ============================================================

echo
echo "=================================================="
echo " [3/10] Waiting for Kubernetes API"
echo "=================================================="

API_READY=false
for ((i=1; i<=MAX_RETRIES; i++)); do
    if kubectl get --raw="/readyz" >/dev/null 2>&1; then
        log_ok "Kubernetes API is ready."
        API_READY=true
        break
    fi
    log_info "Kubernetes API not ready yet..."
    log_info "Attempt ${i}/${MAX_RETRIES}"
    sleep "$RETRY_INTERVAL"
done

if [ "$API_READY" = false ]; then
    log_error "Kubernetes API did not become ready."
    echo
    log_info "Kubelet status:"
    systemctl status kubelet --no-pager || true
    echo
    log_info "Containerd status:"
    systemctl status containerd --no-pager || true
    echo
    log_info "Kubernetes nodes:"
    kubectl get nodes -o wide || true
    exit 1
fi


# ============================================================
# 4. Verify Master Node
# ============================================================

echo
echo "=================================================="
echo " [4/10] Verifying Kubernetes node"
echo "=================================================="

kubectl get nodes -o wide

MASTER_IP=$(kubectl get node "$(hostname)" \
    -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' \
    2>/dev/null || true)

if [ -n "$MASTER_IP" ]; then
    log_info "Kubernetes InternalIP: $MASTER_IP"
else
    log_warn "Unable to determine Kubernetes InternalIP."
fi

# ============================================================
# Verify host-only interface
# ============================================================

echo
log_info "Checking Calico network interface..."
if ip addr show "$CALICO_INTERFACE" >/dev/null 2>&1; then
    log_ok "Interface ${CALICO_INTERFACE} exists."
else
    log_error "Interface ${CALICO_INTERFACE} does not exist."
    echo
    ip -4 addr show
    exit 1
fi

if ip addr show "$CALICO_INTERFACE" | grep -q "$EXPECTED_NODE_IP"; then
    log_ok "Host-only IP ${EXPECTED_NODE_IP} is configured."
else
    log_warn "Expected IP ${EXPECTED_NODE_IP} was not found on ${CALICO_INTERFACE}."
    echo
    ip -4 addr show "$CALICO_INTERFACE"
fi

# ============================================================
# 5. Download Calico Manifest
# ============================================================

echo
echo "=================================================="
echo " [5/10] Downloading Calico manifest"
echo "=================================================="


log_info "Calico version: ${CALICO_VERSION}"
log_info "Downloading manifest..."
if ! curl -fsSL \
    "$CALICO_MANIFEST_URL" \
    -o "$CALICO_MANIFEST"; then
    log_error "Failed to download Calico manifest."
    exit 1
fi

if [ ! -s "$CALICO_MANIFEST" ]; then
    log_error "Downloaded Calico manifest is empty."
    exit 1
fi
log_ok "Calico manifest downloaded."

# ============================================================
# 6. Configure Calico IP autodetection
# ============================================================

echo
echo "=================================================="
echo " [6/10] Configuring Calico IP autodetection"
echo "=================================================="

#
# Calico must use the Kubernetes node-to-node network.
# Our Vagrant VMs have:
#   enp0s3 -> NAT -> 10.0.2.x
#   enp0s8 -> Host-only -> 192.168.56.x
# Kubernetes node communication should use enp0s8.
# Therefore we configure:
#   IP_AUTODETECTION_METHOD=interface=enp0s8
# ============================================================

if grep -q "name: IP_AUTODETECTION_METHOD" "$CALICO_MANIFEST"; then
    log_info "Updating existing IP_AUTODETECTION_METHOD."
    sed -i \
        '/- name: IP_AUTODETECTION_METHOD/{n;s/.*/          value: "interface=enp0s8"/;}' \
        "$CALICO_MANIFEST"
else
    log_info "Adding IP_AUTODETECTION_METHOD."
    sed -i \
        '/- name: IP$/,/value: autodetect/ s/value: autodetect/value: "interface=enp0s8"/' \
        "$CALICO_MANIFEST"
fi

log_ok "Calico IP autodetection configured for ${CALICO_INTERFACE}."

# ============================================================
# 7. Check Existing Calico Installation
# ============================================================

echo
echo "=================================================="
echo " [7/10] Checking existing Calico installation"
echo "=================================================="

CALICO_DAEMONSET_EXISTS=false
CALICO_CONTROLLER_EXISTS=false

if kubectl get daemonset calico-node \
    -n "$KUBE_SYSTEM_NAMESPACE" \
    >/dev/null 2>&1; then

    CALICO_DAEMONSET_EXISTS=true
fi

if kubectl get deployment calico-kube-controllers \
    -n "$KUBE_SYSTEM_NAMESPACE" \
    >/dev/null 2>&1; then
    CALICO_CONTROLLER_EXISTS=true
fi


if [ "$CALICO_DAEMONSET_EXISTS" = true ]; then
    log_info "Existing calico-node DaemonSet found."
else
    log_info "calico-node DaemonSet does not exist."
fi

if [ "$CALICO_CONTROLLER_EXISTS" = true ]; then
    log_info "Existing Calico controller found."
else
    log_info "Calico controller does not exist."
fi


# ============================================================
# Determine whether existing Calico is healthy
# ============================================================


CALICO_HEALTHY=false


if [ "$CALICO_DAEMONSET_EXISTS" = true ]; then
    DESIRED=$(kubectl get daemonset calico-node \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o jsonpath='{.status.desiredNumberScheduled}' \
        2>/dev/null || echo "0")

    READY=$(kubectl get daemonset calico-node \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o jsonpath='{.status.numberReady}' \
        2>/dev/null || echo "0")

    AVAILABLE=$(kubectl get daemonset calico-node \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o jsonpath='{.status.numberAvailable}' \
        2>/dev/null || echo "0")


    log_info "Existing Calico status:"
    log_info "Desired    : ${DESIRED}"
    log_info "Ready      : ${READY}"
    log_info "Available  : ${AVAILABLE}"


    if [ "$DESIRED" != "0" ] &&
       [ "$READY" = "$DESIRED" ] &&
       [ "$AVAILABLE" = "$DESIRED" ]; then
        CALICO_HEALTHY=true
    fi

fi


# ============================================================
# If Calico is healthy, don't reinstall
# ============================================================

if [ "$CALICO_HEALTHY" = true ]; then
    echo
    log_ok "Existing Calico installation is healthy."
    echo
    log_info "Skipping Calico reinstall."
else
    echo
    log_warn "Calico is missing or incomplete."
    echo
    log_info "Calico will be reconciled using:"
    log_info "Version: ${CALICO_VERSION}"
    # ========================================================
    # Check for old/incomplete installation
    # ========================================================

    if [ "$CALICO_DAEMONSET_EXISTS" = true ] ||
       [ "$CALICO_CONTROLLER_EXISTS" = true ]; then
        echo
        log_warn "Existing incomplete Calico resources detected."
        log_info "Attempting to apply the selected Calico manifest."
    fi


    # ========================================================
    # Validate manifest before applying
    # ========================================================

    echo
    log_info "Running server-side dry run..."
    if ! kubectl apply \
        --dry-run=server \
        -f "$CALICO_MANIFEST" >/tmp/calico-dry-run.log 2>&1; then
        log_error "Calico manifest failed Kubernetes validation."
        echo
        log_error "Validation output:"
        cat /tmp/calico-dry-run.log
        echo
        log_error "Calico was NOT installed."
        exit 1
    fi
    log_ok "Calico manifest passed server-side validation."

    # ========================================================
    # Apply Calico
    # ========================================================

    echo
    log_info "Applying Calico manifest..."
    if ! kubectl apply -f "$CALICO_MANIFEST"; then
        log_error "Calico installation failed."
        echo
        log_info "Calico DaemonSet:"
        kubectl get daemonset calico-node \
            -n "$KUBE_SYSTEM_NAMESPACE" \
            -o wide || true

        echo
        log_info "Calico Pods:"
        kubectl get pods \
            -n "$KUBE_SYSTEM_NAMESPACE" \
            -l k8s-app=calico-node \
            -o wide || true

        echo
        log_info "Recent events:"
        kubectl get events \
            -n "$KUBE_SYSTEM_NAMESPACE" \
            --sort-by='.lastTimestamp' \
            | tail -40 || true

        exit 1

    fi
    log_ok "Calico manifest applied."

fi


# ============================================================
# 8. Wait for Calico DaemonSet
# ============================================================

echo
echo "=================================================="
echo " [8/10] Waiting for Calico nodes"
echo "=================================================="

CALICO_READY=false

for ((i=1; i<=MAX_RETRIES; i++)); do
    DESIRED=$(kubectl get daemonset calico-node \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o jsonpath='{.status.desiredNumberScheduled}' \
        2>/dev/null || echo "0")

    READY=$(kubectl get daemonset calico-node \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o jsonpath='{.status.numberReady}' \
        2>/dev/null || echo "0")

    AVAILABLE=$(kubectl get daemonset calico-node \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o jsonpath='{.status.numberAvailable}' \
        2>/dev/null || echo "0")


    echo "[WAIT] Calico: ${READY}/${DESIRED} ready, ${AVAILABLE} available - attempt ${i}/${MAX_RETRIES}"


    if [ "$DESIRED" != "0" ] &&
       [ "$READY" = "$DESIRED" ] &&
       [ "$AVAILABLE" = "$DESIRED" ]; then
        CALICO_READY=true
        log_ok "All Calico nodes are ready."
        break
    fi
    sleep "$RETRY_INTERVAL"
done

# ============================================================
# Calico failure diagnostics
# ============================================================

if [ "$CALICO_READY" = false ]; then
    echo
    log_error "Calico did not become ready."
    echo
    log_info "DaemonSet:"
    kubectl get daemonset calico-node \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o wide || true

    echo
    log_info "Calico Pods:"
    kubectl get pods \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -l k8s-app=calico-node \
        -o wide || true

    echo
    log_info "Calico Pod descriptions:"

    kubectl describe pods \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -l k8s-app=calico-node \
        2>/dev/null | tail -100 || true

    echo
    log_info "Recent Kubernetes events:"

    kubectl get events \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        --sort-by='.lastTimestamp' \
        | tail -50 || true

    exit 1

fi


# ============================================================
# Wait for Calico Controller
# ============================================================

echo
log_info "Waiting for Calico controller..."

if kubectl rollout status \
    deployment/calico-kube-controllers \
    -n "$KUBE_SYSTEM_NAMESPACE" \
    --timeout=300s; then
    log_ok "Calico controller is ready."

else

    log_warn "Calico controller did not become ready within timeout."
    kubectl get deployment calico-kube-controllers \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -o wide || true
fi

# ============================================================
# 9. Wait for CoreDNS
# ============================================================

echo
echo "=================================================="
echo " [9/10] Waiting for CoreDNS"
echo "=================================================="

if kubectl wait \
    --namespace "$KUBE_SYSTEM_NAMESPACE" \
    --for=condition=Ready \
    pod \
    -l k8s-app=kube-dns \
    --timeout=300s; then
    log_ok "CoreDNS is ready."
else

    log_warn "CoreDNS did not become ready within timeout."
    kubectl get pods \
        -n "$KUBE_SYSTEM_NAMESPACE" \
        -l k8s-app=kube-dns \
        -o wide || true

fi


# ============================================================
# 10. Final Verification
# ============================================================

echo
echo "=================================================="
echo " [10/10] Final Kubernetes Networking Verification"
echo "=================================================="

echo
echo "-------------------- Nodes -----------------------"
kubectl get nodes -o wide

echo
echo "-------------------- Calico ----------------------"
kubectl get daemonset calico-node \
    -n "$KUBE_SYSTEM_NAMESPACE" \
    -o wide
echo
kubectl get pods \
    -n "$KUBE_SYSTEM_NAMESPACE" \
    -l k8s-app=calico-node \
    -o wide
echo
echo "---------------- Calico Controller ---------------"
kubectl get deployment calico-kube-controllers \
    -n "$KUBE_SYSTEM_NAMESPACE" \
    -o wide
echo
echo "-------------------- CoreDNS ----------------------"

kubectl get pods \
    -n "$KUBE_SYSTEM_NAMESPACE" \
    -l k8s-app=kube-dns \
    -o wide
echo
echo "---------------- Calico Node IP -------------------"

kubectl get node "$(hostname)" \
    -o jsonpath='{.metadata.annotations.projectcalico\.org/IPv4Address}'
echo
echo
echo "=================================================="
echo " Calico installation completed successfully"
echo "=================================================="

echo
echo "Calico version:"
echo "$CALICO_VERSION"

echo
echo "Calico interface:"
echo "$CALICO_INTERFACE"

echo
echo "Expected node IP:"
echo "$EXPECTED_NODE_IP"

echo
echo "=================================================="