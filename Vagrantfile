# Kubernetes Cluster Setup with Vagrant
# This Vagrantfile automates the creation of a 3-node Kubernetes cluster using VirtualBox
# - 1 Master node (4GB RAM, 2 CPUs)
# - 2 Worker nodes (2GB RAM each, 2 CPUs each)
# All nodes run Ubuntu Jammy 64-bit

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"

  # Define the cluster nodes with their specifications
  nodes = [
    {name: "master", ip: "192.168.56.10", ssh_port: 2222, cpu: 2, memory: 4096},
    {name: "worker1", ip: "192.168.56.11", ssh_port: 2223, cpu: 2, memory: 2048},
    {name: "worker2", ip: "192.168.56.12", ssh_port: 2224, cpu: 2, memory: 2048}
  ]

  # Create and configure each node
  nodes.each do |node|
    config.vm.define node[:name] do |node_config|
      node_config.vm.hostname = node[:name]
      # Configure private network with static IP for cluster communication
      node_config.vm.network "private_network", ip: node[:ip]

      # Assign a unique host SSH port per machine to avoid conflicts
      node_config.vm.network "forwarded_port", guest: 22, host: node[:ssh_port], id: "ssh", auto_correct: true
      node_config.ssh.insert_key = false
      node_config.ssh.max_tries = 20
      node_config.ssh.timeout = 120

      # Configure VirtualBox provider with specified CPU and memory
      node_config.vm.provider "virtualbox" do |vb|
        vb.memory = node[:memory]
        vb.cpus = node[:cpu]
      end
    end
  end
end