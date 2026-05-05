Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # Disable default synced folder (improves performance & avoids issues)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Global SSH settings (more resilient)
  config.ssh.insert_key = false
  config.ssh.keep_alive = true
  # config.ssh.max_tries = 20
  # config.ssh.timeout = 300

  # Define cluster nodes
  nodes = [
    { name: "master",  ip: "192.168.56.10", cpu: 3, memory: 4096 },
    { name: "worker1", ip: "192.168.56.11", cpu: 2, memory: 2048 },
    { name: "worker2", ip: "192.168.56.12", cpu: 2, memory: 2048 }
  ]

  nodes.each do |node|
    config.vm.define node[:name] do |node_config|
      node_config.vm.hostname = node[:name]

      # ✅ Use fixed host-only adapter (prevents random creation)
      node_config.vm.network "private_network",
        ip: node[:ip],
        virtualbox__hostonly: "vboxnet0"

      # Provider config
      node_config.vm.provider "virtualbox" do |vb|
        vb.name = node[:name]
        vb.memory = node[:memory]
        vb.cpus = node[:cpu]

        # Stability tweaks
        vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
        vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
      end

      # ✅ Idempotent network fix (handles Ubuntu netplan issues)
      node_config.vm.provision "shell", inline: <<-SHELL
        echo "[INFO] Fixing network..."
        sudo netplan apply || true
        sudo systemctl restart systemd-networkd || true
      SHELL
    end
  end
end