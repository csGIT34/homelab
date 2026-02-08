# Homelab Infrastructure

IaC-driven homelab running Proxmox VE across 3 nodes, provisioning Kubernetes (k3s), PostgreSQL, and on-demand sandbox VMs with Terraform, Packer, and Ansible.

## Architecture

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  pve-identity   │  │    pve-r720     │  │   pve-desktop   │
│  Intel E3-1230  │  │  2x E5-2670    │  │   Ryzen 5900x   │
│  32GB RAM       │  │  128GB RAM      │  │   32GB RAM      │
│                 │  │                 │  │                 │
│  dc-01 (AD/DNS/ │  │  k3s-agent-01  │  │  k3s-server-01  │
│    Entra Connect)│  │  k3s-agent-02  │  │                 │
│  dc-02 (AD/DNS) │  │  k3s-agent-03  │  │                 │
│  dc-03 (AD/DNS) │  │  postgres-01   │  │                 │
│                 │  │  sandbox VMs   │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                     US-24-250W Switch (trunk)
                              │
                         USG 4 Pro
                              │
                          Internet
```

## Network

| VLAN | Name | Subnet | Purpose |
|------|------|--------|---------|
| 10 | Management | 10.0.10.0/24 | Proxmox, admin access |
| 20 | Kubernetes | 10.0.20.0/24 | k3s cluster |
| 30 | Database | 10.0.30.0/24 | PostgreSQL |
| 40 | Sandbox | 10.0.40.0/24 | Test VMs |
| 50 | Work | 10.0.50.0/24 | Work WiFi |
| 60 | Personal | 10.0.60.0/24 | Personal WiFi |
| 70 | IoT | 10.0.70.0/24 | Smart devices |
| 80 | Guest | 10.0.80.0/24 | Guest WiFi |

See [docs/network.md](docs/network.md) for full VLAN map, firewall rules, and IP assignments.

## Toolchain

| Tool | Purpose |
|------|---------|
| Proxmox VE 9.x | Hypervisor |
| Terraform + bpg/proxmox | VM provisioning |
| Packer | VM template builds |
| Cloud-init | First-boot config |
| Ansible | Post-provisioning (k3s, PostgreSQL) |
| k3s | Lightweight Kubernetes |

## Quick Start

### 1. Build VM Template

```bash
cd packer/ubuntu-2404/
packer init .
packer build -var-file=variables.pkr.hcl .
```

### 2. Provision Infrastructure

```bash
# k3s cluster
cd terraform/stacks/k3s-cluster/
terraform init && terraform plan
terraform apply

# PostgreSQL
cd ../database/
terraform init && terraform apply

# Sandbox (set vm_count > 0 in terraform.tfvars)
cd ../sandbox/
terraform init && terraform apply
```

### 3. Configure Services

```bash
cd ansible/
ansible-playbook playbooks/site.yml
```

### 4. Access Cluster

```bash
export KUBECONFIG=ansible/kubeconfig
kubectl get nodes
```

## Repository Structure

```
homelab/
├── packer/ubuntu-2404/       # VM template (Packer + cloud-init autoinstall)
├── terraform/
│   ├── modules/proxmox-vm/   # Reusable VM module
│   └── stacks/
│       ├── k3s-cluster/      # k3s control plane + workers
│       ├── database/         # PostgreSQL
│       └── sandbox/          # On-demand test VMs
├── ansible/                  # Post-provisioning playbooks + roles
├── cloud-init/               # Cloud-init configs (base, k8s, postgres)
├── scripts/                  # Proxmox host setup, API token generation
└── docs/                     # Network design, Unifi setup, AD migration
```

## Documentation

- [Network Architecture](docs/network.md) — VLANs, firewall rules, IP assignments
- [Unifi Setup](docs/unifi-setup.md) — USG Pro + AP configuration
- [AD Migration](docs/ad-migration.md) — Domain migration runbook
