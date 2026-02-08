# Active Directory Migration Runbook

Migrate the existing 3-domain AD forest from Hyper-V to the dedicated Proxmox identity server (pve-identity). Each domain gets its own DC. Entra Connect moves to dc-01.

## AD Forest Structure (preserved as-is)

```
azureskylab.net (forest root)
+-- mis.azureskylab.net (child domain)
+-- mas.azureskylab.net (child domain)
```

## VM Layout on pve-identity

| VM | vCPU | RAM | Disk | Domain | Role |
|----|------|-----|------|--------|------|
| dc-01 | 2 | 4GB | 40GB | azureskylab.net | Forest root DC + DNS + Entra Connect |
| dc-02 | 2 | 4GB | 32GB | mis.azureskylab.net | Child domain DC + DNS |
| dc-03 | 2 | 4GB | 32GB | mas.azureskylab.net | Child domain DC + DNS |

All VMs on VLAN 10 (Management), stored on `local-ssd`.

## Pre-Migration Checklist

- [ ] Document all user accounts, groups, and computer objects in each domain
- [ ] Export GPOs from all 3 domains: `Backup-GPO -All -Path C:\GPOBackups`
- [ ] Document FSMO role holders per domain: `netdom query fsmo`
- [ ] Document DNS zones and conditional forwarders
- [ ] Document Entra Connect sync rules and filtering
- [ ] Verify current replication health: `repadmin /replsummary`
- [ ] Take full system state backups of all existing DCs
- [ ] Verify trust relationships between root and child domains
- [ ] Network infrastructure configured (see Step 0a below)

## Step 0a -- Configure Network Infrastructure

**Do this first.** Proxmox nodes need VLAN trunking in place before they can be assigned management IPs or pass tagged traffic to VMs.

Follow [docs/unifi-setup.md](unifi-setup.md) to:

1. Create all VLANs (10, 20, 30, 40, 50, 60, 70, 80) in Unifi Controller
2. Configure trunk ports on the Unifi US-24 Switch for Proxmox nodes
3. Configure access ports (neuromancer on VLAN 10, wired IoT on VLAN 70)
4. Set up WiFi SSIDs mapped to VLANs
5. Create firewall rules per [docs/network.md](network.md)

**Verify:** From neuromancer on VLAN 10, confirm you can reach the USG gateway at 10.0.10.1 and that the switch is reachable on its management IP.

## Step 0b -- Stand Up pve-identity

1. Install Proxmox VE on Intel E3-1230 v3 (240GB PNY SSD as boot drive)
2. Configure storage:
   - 240GB PNY SSD — Proxmox OS (`local`, `local-lvm`)
   - 250GB Samsung 850 EVO — `local-ssd` LVM volume group (VM storage)
   - 1TB WD HDD — available for backups (configure later)
   - 3TB WD HDD — **do not touch** (has personal files to recover)
3. Configure networking:
   ```
   auto vmbr0
   iface vmbr0 inet static
       address 10.0.10.11/24
       gateway 10.0.10.1
       bridge-ports eno1
       bridge-stp off
       bridge-fd 0
       bridge-vlan-aware yes
       bridge-vids 10 20 30 40
   ```
4. Run `scripts/proxmox-init.sh pve-identity`
5. Run `scripts/generate-api-token.sh`
6. Upload Windows Server 2022 ISO to `local` storage

## Step 0c -- Migrate azureskylab.net (Forest Root)

### Create dc-01 VM

- 2 vCPU, 4GB RAM, 40GB disk on `local-ssd`
- Network: `vmbr0`, VLAN tag 10
- IP: 10.0.10.10/24
- Install Windows Server 2022 Standard (Desktop Experience)

### Promote dc-01 as additional DC

```powershell
# Install AD DS role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Promote as additional DC in forest root domain
Install-ADDSDomainController `
    -DomainName "azureskylab.net" `
    -InstallDns:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -NoRebootOnCompletion:$false
```

### Verify replication

```powershell
repadmin /replsummary
repadmin /showrepl dc-01
dcdiag /v
```

### Transfer FSMO roles to dc-01

```powershell
# Transfer all 5 forest/domain FSMO roles for azureskylab.net
Move-ADDirectoryServerOperationMasterRole -Identity "dc-01" `
    -OperationMasterRole SchemaMaster, DomainNamingMaster, `
    PDCEmulator, RIDMaster, InfrastructureMaster -Force

# Verify
netdom query fsmo
```

## Step 0d -- Migrate mis.azureskylab.net (Child Domain)

### Create dc-02 VM

- 2 vCPU, 4GB RAM, 32GB disk on `local-ssd`
- Network: `vmbr0`, VLAN tag 10
- IP: 10.0.10.20/24
- Install Windows Server 2022 Standard (Desktop Experience)

### Promote dc-02 as additional DC in child domain

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSDomainController `
    -DomainName "mis.azureskylab.net" `
    -InstallDns:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -NoRebootOnCompletion:$false
```

### Verify and transfer roles

```powershell
repadmin /replsummary
repadmin /showrepl dc-02

# Transfer mis.azureskylab.net domain FSMO roles
Move-ADDirectoryServerOperationMasterRole -Identity "dc-02" `
    -OperationMasterRole PDCEmulator, RIDMaster, InfrastructureMaster -Force

# Verify
netdom query fsmo
```

## Step 0e -- Migrate mas.azureskylab.net (Child Domain)

### Create dc-03 VM

- 2 vCPU, 4GB RAM, 32GB disk on `local-ssd`
- Network: `vmbr0`, VLAN tag 10
- IP: 10.0.10.30/24
- Install Windows Server 2022 Standard (Desktop Experience)

### Promote dc-03 as additional DC in child domain

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSDomainController `
    -DomainName "mas.azureskylab.net" `
    -InstallDns:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -NoRebootOnCompletion:$false
```

### Verify and transfer roles

```powershell
repadmin /replsummary
repadmin /showrepl dc-03

# Transfer mas.azureskylab.net domain FSMO roles
Move-ADDirectoryServerOperationMasterRole -Identity "dc-03" `
    -OperationMasterRole PDCEmulator, RIDMaster, InfrastructureMaster -Force

# Verify
netdom query fsmo
```

## Step 0f -- Migrate Entra Connect

1. **Install Entra Connect on dc-01**:
   - Download latest Azure AD Connect / Entra Connect from Microsoft
   - Run installer, select "Custom" installation
   - Configure password hash sync
   - Set up user/group filtering (match existing sync rules)

2. **Verify sync**:
   ```powershell
   # Force initial sync
   Start-ADSyncSyncCycle -PolicyType Initial

   # Check sync status
   Get-ADSyncScheduler

   # Verify in Entra portal: Users > All Users
   ```

3. **Decommission old Entra Connect** on Hyper-V:
   - Disable sync schedule on old server
   - Uninstall Entra Connect
   - Verify dc-01 is sole sync source

## Step 0g -- Decommission Hyper-V and Stand Up Remaining Nodes

### Demote old DCs

For each old Hyper-V DC (all 3 domains):

```powershell
# On each old DC — demote
Uninstall-ADDSDomainController -DemoteOperationMasterRole -Force
```

After demotion, clean up metadata from the new DCs:
- Remove old server objects in AD Sites and Services
- Clean up DNS records pointing to old DCs
- Verify: `repadmin /replsummary` shows no errors

### Verify all FSMO roles

```powershell
# On dc-01 (forest root) — should hold Schema Master + Domain Naming Master
netdom query fsmo

# On dc-02 (mis child) — should hold RID, PDC, Infrastructure for mis
# On dc-03 (mas child) — should hold RID, PDC, Infrastructure for mas
```

### Wipe R720xd and install Proxmox

1. Wipe R720xd, install Proxmox VE 9.x (pve-r720)
   - Management IP: 10.0.10.12/24
   - Storage: 250GB SSD (boot), 1TB SSD RAID0 (`local-ssd`), 2TB HDD (`local-hdd`)
2. Run `scripts/proxmox-init.sh pve-r720`
3. Run `scripts/generate-api-token.sh`

### Install Proxmox on AMD 5900x

1. Install Proxmox VE 9.x (pve-desktop)
   - Management IP: 10.0.10.13/24
   - Storage: 500GB M.2 (boot), 1TB M.2 (`local-ssd`)
2. Run `scripts/proxmox-init.sh pve-desktop`
3. Run `scripts/generate-api-token.sh`

### (Optional) Create Proxmox cluster

```bash
# On pve-identity (first node)
pvecm create homelab-cluster

# On pve-r720
pvecm add 10.0.10.11

# On pve-desktop
pvecm add 10.0.10.11

# Verify
pvecm status
```

## Post-Migration Verification

- [ ] `repadmin /replsummary` -- No errors on any domain
- [ ] `netdom query fsmo` -- Correct role holders per domain
- [ ] `dcdiag /v` -- All tests pass on dc-01, dc-02, dc-03
- [ ] Trust relationships intact between root and child domains
- [ ] `Start-ADSyncSyncCycle -PolicyType Delta` -- Entra sync succeeds from dc-01
- [ ] Entra portal shows correct synced users
- [ ] All 3 Proxmox nodes accessible at `https://10.0.10.{11,12,13}:8006`
- [ ] DNS resolution works from all VLANs (public resolvers: 1.1.1.1, 8.8.8.8)
- [ ] AD-joined VMs resolve AD DNS via dc-01 (10.0.10.10)
- [ ] Old Hyper-V host fully decommissioned
