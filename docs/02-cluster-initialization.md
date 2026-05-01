# Cluster Initialization

## Prerequisites
- Vagrant installed on your system
- VirtualBox or another supported hypervisor
- The Vagrantfile located in the main source directory

## Step 1: Copy Vagrantfile to Your Working Directory

If you haven't already, copy the Vagrantfile from the main source directory to your working directory:

```powershell
Copy-Item -Path ".\Vagrantfile" -Destination ".\your-working-directory\"
```

## Step 2: Start the Vagrant Machines

Navigate to the directory containing your Vagrantfile and start the Vagrant machines:

```powershell
cd e:\k8s-vagrant-cluster
vagrant up
```

This command will:
- Create and configure all defined virtual machines
- Install any provisioning scripts defined in the Vagrantfile
- Display detailed logs of the initialization process

## Step 3: Verify Vagrant Machines

### Check Machine Status
Verify that all Vagrant machines are running:

```powershell
vagrant status
```

Expected output should show all machines with status: `running`

### SSH into Each Machine
Test connectivity to each machine:

```powershell
vagrant ssh <machine-name>
```

### Verify Network Connectivity
Check if machines can communicate with each other:

```powershell
vagrant ssh <machine-name>
ping <other-machine-ip>
exit
```

### List Running Machines
View all running Vagrant machines on your system:

```powershell
vagrant global-status
```

### Verify Machine Resources
SSH into a machine and check allocated resources:

```powershell
vagrant ssh <machine-name>
free -h          # Check memory
df -h             # Check disk space
nproc             # Check CPU cores
exit
```

## Step 4: Troubleshooting

If machines fail to start:
- Check VirtualBox is installed: `vboxmanage --version`
- Review logs: `vagrant up --debug`
- Destroy and retry: `vagrant destroy -f && vagrant up`

## Next Steps
Once all machines are verified and running, proceed to cluster configuration.