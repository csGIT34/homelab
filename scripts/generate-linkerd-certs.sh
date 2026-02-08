#!/usr/bin/env bash
set -euo pipefail

# Generate Linkerd trust anchor (CA) and issuer certificates using step CLI
# Prerequisites: Install step CLI — https://smallstep.com/docs/step-cli/installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/../ansible/roles/argocd/files"

mkdir -p "${CERT_DIR}"

if [ -f "${CERT_DIR}/ca.crt" ]; then
  echo "Certificates already exist in ${CERT_DIR}"
  echo "Delete them first if you want to regenerate."
  exit 1
fi

# Check for step CLI (binary may be named "step" or "step-cli")
STEP_CMD=""
if command -v step &> /dev/null; then
  STEP_CMD="step"
elif command -v step-cli &> /dev/null; then
  STEP_CMD="step-cli"
else
  echo "Error: 'step' CLI not found."
  echo "Install it: https://smallstep.com/docs/step-cli/installation"
  exit 1
fi

echo "Generating Linkerd trust anchor certificate (10 year validity)..."
${STEP_CMD} certificate create \
  root.linkerd.cluster.local \
  "${CERT_DIR}/ca.crt" "${CERT_DIR}/ca.key" \
  --profile root-ca \
  --no-password --insecure \
  --not-after 87600h

echo "Generating Linkerd issuer certificate (1 year validity)..."
${STEP_CMD} certificate create \
  identity.linkerd.cluster.local \
  "${CERT_DIR}/issuer.crt" "${CERT_DIR}/issuer.key" \
  --profile intermediate-ca \
  --ca "${CERT_DIR}/ca.crt" --ca-key "${CERT_DIR}/ca.key" \
  --no-password --insecure \
  --not-after 8760h

echo ""
echo "Certificates generated in: ${CERT_DIR}"
echo "  ca.crt      - Trust anchor cert (commit to repo)"
echo "  ca.key      - Trust anchor key (vault-encrypt!)"
echo "  issuer.crt  - Issuer cert (commit to repo)"
echo "  issuer.key  - Issuer key (vault-encrypt!)"
echo ""
echo "Next steps:"
echo "  1. Paste the contents of ca.crt into kubernetes/apps/linkerd/linkerd-control-plane.yml"
echo "     under spec.source.helm.valuesObject.identityTrustAnchorsPEM"
echo "  2. Encrypt private keys:"
echo "     ansible-vault encrypt ${CERT_DIR}/ca.key ${CERT_DIR}/issuer.key"
