# 01 - Environment Setup

## Tools Used
- Vagrant
- VirtualBox

## Prerequisites
- Windows 10 or later
- Administrator access
- At least 6GB RAM available
- Virtualization enabled in BIOS

## Installation Steps

### Step 1: Download and Install VirtualBox

1. Visit [VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads)
2. Click on "Windows hosts" to download the installer
3. Run the downloaded `.exe` file
4. Follow the installation wizard:
   - Accept the license agreement
   - Select installation folder (default is fine)
   - Choose components (keep defaults)
   - Allow network interface installation when prompted
5. Click "Finish" and restart your computer if prompted

### Step 2: Download and Install Vagrant

1. Visit [Vagrant Downloads](https://www.vagrantup.com/downloads)
2. Download the Windows 64-bit version
3. Run the downloaded `.msi` installer
4. Follow the installation wizard:
   - Accept the license agreement
   - Choose installation directory (default is fine)
   - Click "Install"
5. Click "Finish" to complete installation
6. Restart your computer to update PATH environment variables

### Step 3: Verify Installation

Open PowerShell or Command Prompt as Administrator and run the following commands:

## Verification Commands

```powershell
# Verify VirtualBox installation
VBoxManage --version

# Verify Vagrant installation
vagrant --version

# Check Vagrant system information
vagrant --debug
```

## Expected Output

- **VirtualBox**: Should display version number (e.g., `7.0.14r161095`)
- **Vagrant**: Should display version number (e.g., `Vagrant 2.4.0`)

## Troubleshooting

- If commands not found, restart your machine or manually add Vagrant to PATH
- Ensure Hyper-V is disabled in Windows if using VirtualBox
- Check BIOS settings to enable virtualization (VT-x or AMD-V)