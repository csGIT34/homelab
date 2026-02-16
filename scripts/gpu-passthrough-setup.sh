#!/usr/bin/env bash
#
# GPU Passthrough Setup for pve-desktop (AMD CPU + NVIDIA 3090)
#
# This is a REFERENCE script — run each section manually on the Proxmox host.
# Do NOT run this script blindly. Rebooting pve-desktop will temporarily
# take down k3s-server-01 (control plane).
#
# Prerequisites:
#   - AMD IOMMU support enabled in BIOS (VT-d / AMD-Vi)
#   - NVIDIA GPU installed in pve-desktop
#
# After completing these steps, create a PCI Resource Mapping named "gpu-3090"
# in Proxmox UI: Datacenter > Resource Mappings > PCI Devices > Add
#
set -euo pipefail

echo "=== Step 1: Identify GPU PCI IDs ==="
echo "Find your NVIDIA GPU and its audio device:"
echo "  lspci -nn | grep -i nvidia"
echo ""
echo "Note the PCI IDs (e.g., 10de:2204,10de:1aef)"
echo "Note the PCI addresses (e.g., 0000:0b:00.0, 0000:0b:00.1)"
echo ""
read -rp "Enter GPU PCI IDs (comma-separated, e.g., 10de:2204,10de:1aef): " GPU_IDS

echo ""
echo "=== Step 2: Enable IOMMU in GRUB ==="
echo "Adding amd_iommu=on iommu=pt to GRUB cmdline..."
if ! grep -q "amd_iommu=on" /etc/default/grub; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_iommu=on iommu=pt"/' /etc/default/grub
    echo "Updated GRUB config"
else
    echo "IOMMU already configured in GRUB"
fi

echo ""
echo "=== Step 3: Load VFIO modules ==="
cat > /etc/modules-load.d/vfio.conf << 'EOF'
vfio
vfio_iommu_type1
vfio_pci
EOF
echo "Created /etc/modules-load.d/vfio.conf"

echo ""
echo "=== Step 4: Blacklist NVIDIA drivers on host ==="
cat > /etc/modprobe.d/blacklist-nvidia.conf << 'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
blacklist nvidia_modeset
EOF
echo "Created /etc/modprobe.d/blacklist-nvidia.conf"

echo ""
echo "=== Step 5: Bind GPU to vfio-pci ==="
cat > /etc/modprobe.d/vfio.conf << EOF
options vfio-pci ids=${GPU_IDS}
EOF
echo "Created /etc/modprobe.d/vfio.conf with IDs: ${GPU_IDS}"

echo ""
echo "=== Step 6: Update initramfs ==="
update-initramfs -u -k all
update-grub

echo ""
echo "=== Step 7: Reboot required ==="
echo "After reboot, verify with:"
echo "  lspci -nnk | grep -A 3 'NVIDIA'"
echo ""
echo "The GPU should show: Kernel driver in use: vfio-pci"
echo ""
echo "=== Step 8: Create PCI Resource Mapping ==="
echo "In Proxmox UI: Datacenter > Resource Mappings > PCI Devices > Add"
echo "  Name: gpu-3090"
echo "  Select the NVIDIA GPU device on pve-desktop"
echo ""
read -rp "Reboot now? [y/N]: " REBOOT
if [[ "${REBOOT}" =~ ^[Yy]$ ]]; then
    reboot
fi
