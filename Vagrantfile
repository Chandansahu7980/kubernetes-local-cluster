# ============================================================
# Kubernetes 3-Node Lab Cluster
# ============================================================
#
# Nodes:
#   master  -> Control Plane
#   worker1 -> Worker
#   worker2 -> Worker
#
# Kubernetes:
#   v1.28.15
#
# Runtime:
#   containerd
#
# Network:
#   192.168.56.0/24
#
# VirtualBox:
#   vboxnet0
# ============================================================


VAGRANT_BOX = "ubuntu/jammy64"
HOST_ONLY_NETWORK = "vboxnet0"


# ============================================================
# Node Configuration
# ============================================================

NODES = [
  {
    name: "master",
    ip: "192.168.56.10",
    cpu: 3,
    memory: 4096,
    role: "master"
  },
  {
    name: "worker1",
    ip: "192.168.56.11",
    cpu: 2,
    memory: 2048,
    role: "worker"
  },
  {
    name: "worker2",
    ip: "192.168.56.12",
    cpu: 2,
    memory: 2048,
    role: "worker"
  }
]


Vagrant.configure("2") do |config|

  # ==========================================================
  # Global Configuration
  # ==========================================================

  config.vm.box = VAGRANT_BOX

  # Disable default /vagrant synced folder.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Use a synced folder for data persistence.
  config.vm.synced_folder "./data", "/vagrant/data",
  type: "virtualbox"
  # Keep Vagrant's default insecure key.
  config.ssh.insert_key = false

  # Keep SSH connections alive.
  config.ssh.keep_alive = true

  # Give VMs enough time to boot.
  config.vm.boot_timeout = 600


  # ==========================================================
  # Define Kubernetes Nodes
  # ==========================================================

  NODES.each do |node|

    config.vm.define node[:name] do |vm|

      # --------------------------------------------------------
      # Basic VM Configuration
      # --------------------------------------------------------

      vm.vm.hostname = node[:name]

      # --------------------------------------------------------
      # Host-Only Network
      # --------------------------------------------------------
      #
      # master  -> 192.168.56.10
      # worker1 -> 192.168.56.11
      # worker2 -> 192.168.56.12
      #
      # Kubernetes node-to-node communication uses this network.
      # --------------------------------------------------------

      vm.vm.network "private_network",
        ip: node[:ip],
        virtualbox__hostonly: HOST_ONLY_NETWORK

      # --------------------------------------------------------
      # VirtualBox Provider
      # --------------------------------------------------------

      vm.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-#{node[:name]}"
        vb.memory = node[:memory]
        vb.cpus = node[:cpu]

        # Paravirtualized network adapter.
        vb.customize [
          "modifyvm",
          :id,
          "--nictype1",
          "virtio"
        ]

        # Disable audio.
        vb.customize [
          "modifyvm",
          :id,
          "--audio-enabled",
          "off"
        ]

        # Disable USB.
        vb.customize [
          "modifyvm",
          :id,
          "--usb",
          "off"
        ]

      end

      # ========================================================
      # Common Provisioning
      # ========================================================
      #
      # Runs on every node:
      #
      # - Disable swap
      # - Kernel modules
      # - Kubernetes networking
      # - containerd
      # - Kubernetes repository
      # - kubeadm
      # - kubelet
      # - kubectl
      #
      # Arguments:
      #
      #   node name
      #   node role
      #
      # ========================================================

      vm.vm.provision "shell",
        path: "scripts/01-common.sh",
        args: [node[:name], node[:role]]


      # ========================================================
      # Role-Specific Provisioning
      # ========================================================

      if node[:role] == "master"

        # ------------------------------------------------------
        # Master Preparation
        # ------------------------------------------------------
        #
        # IMPORTANT:
        # No IP is passed here.
        #
        # 02-master.sh automatically detects the
        # 192.168.56.x address.
        # ------------------------------------------------------

        vm.vm.provision "shell",
          path: "scripts/02-master.sh",
          args: [node[:name]]


        # ------------------------------------------------------
        # Initialize Kubernetes Control Plane
        # ------------------------------------------------------
        #
        # 04-init-cluster.sh automatically detects:
        #
        # master -> 192.168.56.10
        #
        # No IP argument is required.
        # ------------------------------------------------------

        vm.vm.provision "shell",
          path: "scripts/04-init-cluster.sh"


        # ------------------------------------------------------
        # Install Calico CNI
        # ------------------------------------------------------

        vm.vm.provision "shell",
          path: "scripts/05-install-calico.sh"

      elsif node[:role] == "worker"

        # ------------------------------------------------------
        # Worker Preparation
        # ------------------------------------------------------
        #
        # No IP is passed.
        #
        # 03-worker.sh automatically detects the
        # 192.168.56.x address.
        # ------------------------------------------------------

        vm.vm.provision "shell",
          path: "scripts/03-worker.sh",
          args: [node[:name]]
        vm.vm.provision "shell",
        path: "scripts/06-join-worker.sh",
        args: [node[:name]]
      end
    end
  end
end