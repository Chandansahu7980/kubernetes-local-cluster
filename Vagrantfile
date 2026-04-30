Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"

  nodes = [
    {name: "master", ip: "192.168.56.10", cpu: 2, memory: 4096},
    {name: "worker1", ip: "192.168.56.11", cpu: 2, memory: 2048},
    {name: "worker2", ip: "192.168.56.12", cpu: 2, memory: 2048}
  ]

  nodes.each do |node|
    config.vm.define node[:name] do |node_config|
      node_config.vm.hostname = node[:name]
      node_config.vm.network "private_network", ip: node[:ip]

      node_config.vm.provider "virtualbox" do |vb|
        vb.memory = node[:memory]
        vb.cpus = node[:cpu]
      end
    end
  end
end