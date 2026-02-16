# CLAUDE.md

This file provides guidance to Claude Code when working with the homelab repository.

## Project Overview

IaC-driven homelab running Proxmox VE across 3 nodes, provisioning Kubernetes (k3s), PostgreSQL, and on-demand sandbox VMs with Terraform, Packer, and Ansible. Kubernetes workloads are deployed via ArgoCD GitOps.

## Repository Structure

```
homelab/
├── packer/ubuntu-2404/           # VM template (Packer + cloud-init autoinstall)
├── terraform/
│   ├── modules/proxmox-vm/       # Reusable VM module
│   └── stacks/
│       ├── k3s-cluster/          # k3s control plane + workers
│       ├── database/             # PostgreSQL VM
│       ├── ollama/               # Ollama inference server (GPU passthrough)
│       └── sandbox/              # On-demand test VMs
├── ansible/                      # Post-provisioning playbooks + roles
├── cloud-init/                   # Cloud-init configs (base, k8s, postgres)
├── scripts/                      # Proxmox host setup, API token generation
├── kubernetes/
│   ├── root-app.yml              # ArgoCD bootstrap (app-of-apps)
│   ├── projects/                 # ArgoCD AppProjects (NOT auto-synced)
│   │   ├── infrastructure.yml    # For infra services (traefik, cert-manager, etc.)
│   │   └── applications.yml      # For application workloads (external app repos)
│   ├── apps/                     # ArgoCD Applications (auto-synced by root-app)
│   │   ├── cert-manager/
│   │   ├── coredns/
│   │   ├── linkwarden/
│   │   ├── metallb/
│   │   ├── monitoring/
│   │   ├── speedtest-tracker/
│   │   ├── traefik/
│   │   └── workout-tracker/
│   └── manifests/
│       └── ingress/              # Traefik Ingress resources for infra services
└── docs/                         # Network design, Unifi setup, AD migration
```

## Cluster Topology

| Node | IP | Role |
|------|-----|------|
| k3s-server-01 | 10.0.20.10 | Control plane |
| k3s-agent-01 | 10.0.20.21 | Worker |
| k3s-agent-02 | 10.0.20.22 | Worker |
| k3s-agent-03 | 10.0.20.23 | Worker |
| postgres-01 | 10.0.30.10 | External PostgreSQL (VLAN 30) |
| ollama-01 | 10.0.20.30 | Ollama inference server (GPU passthrough, VLAN 20) |

### Key IPs

| Service | IP | DNS |
|---------|-----|-----|
| Traefik LB | 10.0.20.80 | `*.home.lab` ingress |
| CoreDNS LB | 10.0.20.53 | Internal DNS |
| PostgreSQL | 10.0.30.10 | `postgres.home.lab` |
| Ollama | 10.0.20.30 | `ollama.home.lab` |

### Kubeconfig

```bash
# From the k3s server
ssh ubuntu@10.0.20.10 sudo cat /etc/rancher/k3s/k3s.yaml
# Replace 127.0.0.1 with 10.0.20.10, save to ~/.kube/config
```

Or use the Ansible-generated kubeconfig:
```bash
export KUBECONFIG=ansible/kubeconfig
```

## ArgoCD GitOps Architecture

### App-of-Apps Pattern

ArgoCD is bootstrapped via Ansible which applies `kubernetes/root-app.yml`. This root Application watches `kubernetes/apps/` recursively and auto-discovers all Application YAMLs:

```
root-app.yml (applied by Ansible)
  └── watches kubernetes/apps/** (directory, recurse: true)
        ├── cert-manager/cert-manager.yml     → deploys cert-manager Helm chart
        ├── coredns/coredns.yml               → deploys CoreDNS Helm chart
        ├── traefik/traefik.yml               → deploys Traefik Helm chart
        ├── workout-tracker/workout-tracker.yml → syncs external repo k8s/ dir
        └── ...
```

### AppProjects

Two projects control permissions:

- **`infrastructure`** — For infra services deployed from Helm charts or this repo. Has `clusterResourceWhitelist: */*` and scoped namespace destinations.
- **`applications`** — For application workloads, potentially from external repos. Has `clusterResourceWhitelist` for Namespaces and `namespaceResourceWhitelist: */*` with wildcard namespace destinations.

**Important:** AppProjects live in `kubernetes/projects/` which is NOT watched by the root app. Changes to AppProjects must be applied manually:

```bash
kubectl apply -f kubernetes/projects/applications.yml
kubectl apply -f kubernetes/projects/infrastructure.yml
```

### Adding a New Application

1. **Create the Application YAML:**
   ```bash
   mkdir kubernetes/apps/<app-name>/
   ```
   Create `kubernetes/apps/<app-name>/<app-name>.yml`:
   ```yaml
   ---
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: <app-name>
     namespace: argocd
     finalizers:
       - resources-finalizer.argocd.argoproj.io
   spec:
     project: applications  # or infrastructure
     source:
       repoURL: https://github.com/csGIT34/<repo>.git
       targetRevision: main  # or master
       path: k8s/            # path to manifests in the source repo
     destination:
       server: https://kubernetes.default.svc
       namespace: <app-namespace>
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
         - CreateNamespace=true
   ```

2. **If using an external repo,** add it to the AppProject's `sourceRepos`:
   Edit `kubernetes/projects/applications.yml`:
   ```yaml
   sourceRepos:
     - https://github.com/csGIT34/homelab.git
     - https://github.com/csGIT34/<new-repo>.git
   ```
   Then apply manually: `kubectl apply -f kubernetes/projects/applications.yml`

3. **Add DNS entry** in `kubernetes/apps/coredns/coredns.yml` under `zoneFiles[0].contents`:
   ```
   <subdomain>           IN  A    10.0.20.80
   ```
   All web apps route through Traefik at `10.0.20.80`.

4. **Commit and push.** The root app will auto-discover the new Application YAML.

5. **Run any post-deploy steps** (migrations, seeding, etc.) via `kubectl exec`.

### Ingress Pattern (Traefik + TLS)

All HTTPS ingresses follow this pattern using Traefik and cert-manager:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <app-namespace>
  annotations:
    cert-manager.io/cluster-issuer: home-lab-ca
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - secretName: <app-name>-tls
      hosts:
        - <app-name>.home.lab
  rules:
    - host: <app-name>.home.lab
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <service-name>
                port:
                  number: <port>
```

- `home-lab-ca` is a cert-manager ClusterIssuer (internal CA)
- `websecure` is the Traefik HTTPS entrypoint
- TLS certificates are auto-provisioned by cert-manager

### Infrastructure Services

| Service | Namespace | Type | Access |
|---------|-----------|------|--------|
| ArgoCD | argocd | Helm (argo-helm) | https://argocd.home.lab |
| Traefik | traefik | Helm | LB at 10.0.20.80 |
| CoreDNS | coredns | Helm | LB at 10.0.20.53 |
| cert-manager | cert-manager | Helm | Internal CA (`home-lab-ca`) |
| MetalLB | metallb-system | Helm | IP pool: `k8s-vlan-pool` |
| Prometheus + Grafana | monitoring | Helm | https://grafana.home.lab |

### Application Workloads

| App | Namespace | Source Repo | Access |
|-----|-----------|-------------|--------|
| Linkwarden | linkwarden | homelab (kubernetes/manifests/linkwarden/) | https://linkwarden.home.lab |
| Workout Tracker | workout-tracker | csGIT34/workouttracker (k8s/) | https://workout.home.lab |
| Speedtest Tracker | speedtest-tracker | homelab (kubernetes/manifests/speedtest-tracker/) | https://speedtest.home.lab |

## External PostgreSQL

PostgreSQL runs on a dedicated VM at `10.0.30.10` (VLAN 30, Database network), provisioned via Terraform and configured via Ansible.

### Creating a Database for a New App

```bash
# Connect as admin
PGPASSWORD='<admin-password>' psql -h 10.0.30.10 -U postgres

# Create database and user
CREATE DATABASE <appname>;
CREATE USER <appname> WITH ENCRYPTED PASSWORD '<password>';
GRANT ALL PRIVILEGES ON DATABASE <appname> TO <appname>;
\c <appname>
GRANT ALL ON SCHEMA public TO <appname>;
```

### Database Connection String Format

```
postgresql://<user>:<password>@10.0.30.10:5432/<database>
```

Store in a Kubernetes Secret in the app's namespace, referenced by the backend pods.

## Common Tasks

### Deploying Code Changes to an App

For apps using `imagePullPolicy: Always` with `latest` tag:

```bash
# 1. Push code to git (ArgoCD syncs k8s manifests automatically)
# 2. Build and push Docker images
docker build -t <registry>/<image>:latest -f <Dockerfile> .
docker push <registry>/<image>:latest
# 3. Restart deployments to pull new images
kubectl rollout restart deployment/<name> -n <namespace>
```

For proper GitOps, apps should have a CI pipeline (GitHub Actions) that builds images on push. See the workout tracker repo for an example.

### Checking ArgoCD Status

```bash
kubectl get applications -n argocd
kubectl get application <name> -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}'
# Force refresh
kubectl annotate application <name> -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Debugging a Failed Sync

```bash
kubectl get application <name> -n argocd -o jsonpath='{.status.operationState.syncResult.resources}' | python3 -m json.tool
```

Common issues:
- **"resource not permitted in project"** — Update the AppProject's `sourceRepos`, `destinations`, or resource whitelists, then `kubectl apply` the project file
- **Stuck retrying old revision** — Clear the operation: `kubectl patch application <name> -n argocd --type merge -p '{"operation": null}'`

## Secrets Management

All secrets are stored in `pass` (GPG-backed password store) under the `homelab/` prefix.

```bash
# List all secrets
pass homelab/

# Retrieve a secret
pass homelab/<app>/<key-name>

# Store a new secret
echo 'value' | pass insert -e homelab/<app>/<key-name>
```

### Secret Inventory

| pass path | K8s Secret | Namespace | Description |
|-----------|-----------|-----------|-------------|
| `homelab/glance/github-token` | glance-secrets | glance | GitHub API token for repo widget |
| `homelab/glance/jellyfin-api-key` | glance-secrets | glance | Jellyfin API key for media widgets |
| `homelab/glance/unifi-api-key` | glance-secrets | glance | Unifi controller API key |
| `homelab/glance/speedtest-tracker-api-token` | glance-secrets | glance | Speedtest Tracker API token |
| `homelab/linkwarden/*` | linkwarden-secrets | linkwarden | DB password, NextAuth, Meili key, API key |
| `homelab/proxmox/monitoring-*` | pve-exporter-credentials | monitoring | PVE API token (`prometheus@pve!monitoring`) |
| `homelab/unifi/unpoller-*` | unpoller-credentials | monitoring | UnPoller read-only user credentials |
| `homelab/speedtest-tracker/app-key` | speedtest-tracker-secrets | speedtest-tracker | Laravel APP_KEY |
| `homelab/pgadmin/*` | pgadmin-credentials | pgadmin | Default admin email and password |
| `homelab/corpocache/*` | corpocache-secret | corpocache | PostgreSQL connection details |
| `homelab/workout-tracker/*` | workout-tracker-secrets | workout-tracker | PostgreSQL URL, JWT secrets |

### Recreating a K8s Secret from pass

```bash
# Example: recreate linkwarden-secrets
kubectl create secret generic linkwarden-secrets -n linkwarden \
  --from-literal=NEXTAUTH_SECRET="$(pass homelab/linkwarden/nextauth-secret)" \
  --from-literal=NEXTAUTH_URL="https://linkwarden.home.lab/api/v1/auth" \
  --from-literal=DATABASE_URL="$(pass homelab/linkwarden/database-url)" \
  --from-literal=MEILI_MASTER_KEY="$(pass homelab/linkwarden/meili-master-key)"
```

## Documentation

- [docs/network.md](docs/network.md) — VLANs, firewall rules, IP assignments
- [docs/unifi-setup.md](docs/unifi-setup.md) — USG Pro + AP configuration
- [docs/ad-migration.md](docs/ad-migration.md) — Domain migration runbook
