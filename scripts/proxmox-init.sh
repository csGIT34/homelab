#!/usr/bin/env bash
# proxmox-init.sh — One-time Proxmox host setup
# Run on each Proxmox node after fresh install.
#
# Usage: bash scripts/proxmox-init.sh <node-name>
# Example: bash scripts/proxmox-init.sh pve-identity

set -euo pipefail

NODE_NAME="${1:?Usage: $0 <node-name> (pve-identity|pve-r720|pve-desktop)}"

echo "=== Proxmox Init: ${NODE_NAME} ==="

# --- Disable enterprise repo (no subscription) ---
ENTERPRISE_LIST="/etc/apt/sources.list.d/pve-enterprise.list"
if [ -f "$ENTERPRISE_LIST" ]; then
    echo "Disabling enterprise repository..."
    sed -i 's/^deb/#deb/' "$ENTERPRISE_LIST"
fi

# --- Add no-subscription repo ---
NO_SUB_LIST="/etc/apt/sources.list.d/pve-no-subscription.list"
if [ ! -f "$NO_SUB_LIST" ]; then
    echo "Adding no-subscription repository..."
    echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > "$NO_SUB_LIST"
fi

# --- Update and install base packages ---
echo "Updating packages..."
apt-get update -y
apt-get dist-upgrade -y
apt-get install -y \
    vim \
    htop \
    iotop \
    curl \
    wget \
    net-tools \
    sudo \
    libguestfs-tools \
    cloud-init

# --- Remove subscription nag ---
NAGS_JS="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
if grep -q "No valid subscription" "$NAGS_JS" 2>/dev/null; then
    echo "Removing subscription nag..."
    sed -Ei.bak "s/Ext\.Msg\.show\(\{[^}]*No valid subscription[^}]*\}\);//g" "$NAGS_JS"
    systemctl restart pveproxy
fi

# --- Configure storage pools based on node ---
configure_storage() {
    local node="$1"
    case "$node" in
        pve-identity)
            echo "Storage: 240GB PNY SSD (boot), 250GB Samsung SSD (local-ssd), 1TB HDD (later), 3TB HDD (DO NOT TOUCH)"
            echo ">> Create LVM storage for the 250GB Samsung SSD:"
            echo "   1. Identify the Samsung disk: lsblk -o NAME,SIZE,MODEL"
            echo "   2. Wipe if needed: wipefs -a /dev/sdX && sgdisk --zap-all /dev/sdX"
            echo "   3. pvcreate /dev/sdX"
            echo "   4. vgcreate local-ssd /dev/sdX"
            echo "   5. pvesm add lvm local-ssd --vgname local-ssd --content images,rootdir"
            ;;
        pve-r720)
            echo "Storage: 1TB SSD RAID0 (local-ssd), 2TB HDD (local-hdd)"
            echo ">> Configure these manually in Proxmox UI or with pvesm:"
            echo "   pvesm add dir local-ssd --path /mnt/local-ssd --content images,rootdir,iso"
            echo "   pvesm add dir local-hdd --path /mnt/local-hdd --content backup,iso,snippets"
            ;;
        pve-desktop)
            echo "Storage: 1TB M.2 (local-ssd)"
            echo ">> Configure these manually in Proxmox UI or with pvesm:"
            echo "   pvesm add dir local-ssd --path /mnt/local-ssd --content images,rootdir,iso"
            ;;
        *)
            echo "Unknown node: $node"
            exit 1
            ;;
    esac
}

configure_storage "$NODE_NAME"

# --- Enable VLAN-aware bridge ---
echo ""
echo "=== Network Configuration ==="
echo "Ensure /etc/network/interfaces has a VLAN-aware bridge:"
echo ""
echo "  auto vmbr0"
echo "  iface vmbr0 inet static"
echo "      address 10.0.10.X/24    # Set per node: .11, .12, .13"
echo "      gateway 10.0.10.1"
echo "      bridge-ports eno1       # Adjust interface name"
echo "      bridge-stp off"
echo "      bridge-fd 0"
echo "      bridge-vlan-aware yes"
echo "      bridge-vids 10 20 30 40"
echo ""
echo "Edit /etc/network/interfaces and run: ifreload -a"

# --- Set hostname ---
echo "Setting hostname to ${NODE_NAME}..."
hostnamectl set-hostname "$NODE_NAME"

# --- Enable IOMMU (for PCI passthrough if needed) ---
if grep -q "Intel" /proc/cpuinfo; then
    echo "Intel CPU detected. For IOMMU, add 'intel_iommu=on' to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
elif grep -q "AMD" /proc/cpuinfo; then
    echo "AMD CPU detected. For IOMMU, add 'amd_iommu=on' to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
fi

echo ""
echo "=== Proxmox Init Complete ==="
echo "Next steps:"
echo "  1. Configure /etc/network/interfaces (see above)"
echo "  2. Mount and configure storage pools"
echo "  3. Run scripts/generate-api-token.sh for Terraform access"
echo "  4. Reboot: reboot"
