#!/usr/bin/env bash
# generate-api-token.sh — Create a Terraform API user and token on Proxmox
# Run on each Proxmox node (or once if clustered).
#
# Usage: bash scripts/generate-api-token.sh

set -euo pipefail

TF_USER="terraform@pve"
TF_TOKEN_ID="terraform-token"
TF_ROLE="TerraformProv"

echo "=== Creating Terraform API Token ==="

# --- Create custom role with required permissions ---
echo "Creating role: ${TF_ROLE}..."
pveum role add "$TF_ROLE" -privs \
    "Datastore.AllocateSpace,Datastore.Audit,Pool.Allocate,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.Monitor,VM.PowerMgmt,SDN.Use" \
    2>/dev/null || echo "Role ${TF_ROLE} already exists, skipping."

# --- Create user ---
echo "Creating user: ${TF_USER}..."
pveum user add "$TF_USER" --comment "Terraform automation user" 2>/dev/null || echo "User ${TF_USER} already exists, skipping."

# --- Assign role to user ---
echo "Assigning role ${TF_ROLE} to ${TF_USER}..."
pveum aclmod / -user "$TF_USER" -role "$TF_ROLE"

# --- Generate API token ---
echo "Generating API token..."
TOKEN_OUTPUT=$(pveum user token add "$TF_USER" "$TF_TOKEN_ID" --privsep 0 2>/dev/null) || {
    echo "Token ${TF_TOKEN_ID} may already exist. To regenerate:"
    echo "  pveum user token remove ${TF_USER} ${TF_TOKEN_ID}"
    echo "  Then re-run this script."
    exit 1
}

echo ""
echo "=== Token Created Successfully ==="
echo "$TOKEN_OUTPUT"
echo ""
echo "Save these values for Terraform provider configuration:"
echo ""
echo "  PROXMOX_VE_API_TOKEN=\"${TF_USER}!${TF_TOKEN_ID}=<token-value-above>\""
echo "  PROXMOX_VE_ENDPOINT=\"https://10.0.10.X:8006\""
echo ""
echo "Export as environment variables or add to terraform.tfvars (excluded from git)."
