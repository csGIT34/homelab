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
│   │   ├── workout-tracker/
│   │   └── forgejo/              # Forgejo server + runner
│   └── manifests/
│       ├── ingress/              # Traefik Ingress resources for infra services
│       └── forgejo-runner/       # Forgejo Actions runner + DinD sidecar
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
| Forgejo SSH | 10.0.20.81 | `git.home.lab` (SSH) |

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
       repoURL: https://git.home.lab/csGIT34/<repo>.git
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
     - https://git.home.lab/csGIT34/<new-repo>.git
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
| Forgejo | forgejo | Helm (forgejo-helm) | https://git.home.lab |

### Application Workloads

| App | Namespace | Source Repo | Access |
|-----|-----------|-------------|--------|
| Linkwarden | linkwarden | homelab (kubernetes/manifests/linkwarden/) | https://linkwarden.home.lab |
| Workout Tracker | workout-tracker | Forgejo csGIT34/workouttracker (k8s/) | https://workout.home.lab |
| CorpoCache | corpocache | Forgejo csGIT34/CorpoCache (helm/) | https://cache.home.lab |
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

For proper GitOps, apps should have a Forgejo Actions CI pipeline that builds images on push and pushes to Harbor. See the Forgejo CI/CD section below.

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
| `homelab/forgejo/*` | forgejo-db-secret, forgejo-app-secrets, forgejo-admin-secret | forgejo | DB password, secret key, internal token, JWT secrets, admin credentials |
| `homelab/forgejo/runner-registration-token` | forgejo-runner-secret | forgejo | Forgejo Actions runner registration token |
| `homelab/forgejo/harbor-robot-secret` | forgejo-runner-harbor-secret | forgejo | Harbor robot account for CI image push |

### Recreating a K8s Secret from pass

```bash
# Example: recreate linkwarden-secrets
kubectl create secret generic linkwarden-secrets -n linkwarden \
  --from-literal=NEXTAUTH_SECRET="$(pass homelab/linkwarden/nextauth-secret)" \
  --from-literal=NEXTAUTH_URL="https://linkwarden.home.lab/api/v1/auth" \
  --from-literal=DATABASE_URL="$(pass homelab/linkwarden/database-url)" \
  --from-literal=MEILI_MASTER_KEY="$(pass homelab/linkwarden/meili-master-key)"
```

## Forgejo CI/CD

### Architecture

Forgejo (`git.home.lab`) is the primary git remote for application repos. It provides GitHub Actions-compatible CI via Forgejo Actions.

```
Developer pushes to Forgejo (git@git.home.lab)
  → Forgejo Actions triggers CI workflow
    → Runner builds Docker image (DinD sidecar)
    → Pushes to Harbor (registry.home.lab)
  → Forgejo push-mirrors to GitHub (backup)
  → ArgoCD watches Forgejo repo for k8s manifest changes → deploys
```

**Components:**
- **Forgejo server** — Helm chart via ArgoCD (`kubernetes/apps/forgejo/forgejo.yml`), external PG + Redis, Traefik ingress (HTTP+HTTPS), SSH via MetalLB LoadBalancer at `10.0.20.81`
- **Forgejo runner** — Raw k8s manifests (`kubernetes/manifests/forgejo-runner/`), DinD sidecar (privileged) for Docker builds
- **Harbor** — Container registry at `registry.home.lab`, robot account `robot$forgejo-ci` for CI push access

### Runner Configuration

The runner uses Docker-in-Docker (DinD) to build images inside CI jobs:

- **Runner image**: `code.forgejo.org/forgejo/runner:6.3.1`
- **DinD image**: `docker:27-dind` with `--insecure-registry=registry.home.lab`
- **Instance URL**: `http://git.home.lab` (HTTP, not HTTPS — runner runs as non-root, can't install CA certs)
- **Job container DNS**: `--dns 10.0.20.53` (external CoreDNS, resolves `git.home.lab` and `registry.home.lab`)
- **Docker socket**: Mounted into job containers via `-v /var/run/docker.sock:/var/run/docker.sock`
- **Labels**: `ubuntu-latest` → `node:20-bookworm`, `docker` → `docker:27`

Config files:
- `kubernetes/manifests/forgejo-runner/deployment.yml` — Runner + DinD sidecar Deployment
- `kubernetes/manifests/forgejo-runner/configmap.yml` — Runner config (labels, capacity, DNS, container options)
- `kubernetes/manifests/forgejo-runner/ca-configmap.yml` — Home Lab root CA cert for DinD

### CI Workflow Pattern

Each app repo has `.forgejo/workflows/ci.yml`:

```yaml
name: Build and Push
on:
  push:
    branches: [main]
    paths-ignore:
      - "k8s/**"
      - "*.md"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Docker CLI
        run: |
          apt-get update && apt-get install -y docker.io
      - name: Login to Harbor
        env:
          HARBOR_USER: ${{ secrets.HARBOR_USERNAME }}
          HARBOR_PASS: ${{ secrets.HARBOR_PASSWORD }}
        run: echo "$HARBOR_PASS" | docker login registry.home.lab -u "$HARBOR_USER" --password-stdin
      - name: Build and push
        run: |
          docker build -t registry.home.lab/csgit34/<image>:${{ github.sha }} -t registry.home.lab/csgit34/<image>:latest .
          docker push registry.home.lab/csgit34/<image>:${{ github.sha }}
          docker push registry.home.lab/csgit34/<image>:latest
```

**Important:** Harbor credentials MUST use `env:` vars (not inline `${{ secrets.* }}`). The `$` in `robot$forgejo-ci` gets interpreted by bash if placed directly in double-quoted strings.

### Adding CI to a New Repo

1. **Create Harbor project** (if needed) for the image namespace
2. **Add Forgejo repo secrets** (Settings → Actions → Secrets):
   - `HARBOR_USERNAME`: `robot$forgejo-ci`
   - `HARBOR_PASSWORD`: value from `pass homelab/forgejo/harbor-robot-secret`
3. **Create workflow** at `.forgejo/workflows/ci.yml` following the pattern above
4. **Push to Forgejo** — CI triggers automatically

### Push Mirroring

Repos on Forgejo are push-mirrored to GitHub as backup (sync-on-commit + 8h interval). Configure via Forgejo UI: **Repo Settings → Repository → Mirror Settings → Add Push Mirror**.

GitHub PAT stored at `pass homelab/forgejo/github-mirror-pat` (needs `repo` scope).

### Git Remotes

Local repos use Forgejo as `origin` and GitHub as `github`:

```bash
git remote -v
# origin   git@git.home.lab:csGIT34/<repo>.git (Forgejo, primary)
# github   git@github.com:csGIT34/<repo>.git (GitHub, backup)
```

SSH config for Forgejo (`~/.ssh/config`):
```
Host git.home.lab
  HostName 10.0.20.81
  User git
```

## Documentation

- [docs/network.md](docs/network.md) — VLANs, firewall rules, IP assignments
- [docs/unifi-setup.md](docs/unifi-setup.md) — USG Pro + AP configuration
- [docs/ad-migration.md](docs/ad-migration.md) — Domain migration runbook
