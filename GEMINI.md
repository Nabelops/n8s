# GEMINI.md - Homelab GitOps Project

## Project Overview
This repository manages the deployment of services to a home lab Kubernetes cluster (referred to as `n8s`). It uses a **GitOps** approach with **ArgoCD** and **Kustomize**.

- **Main Technologies:** Kubernetes, ArgoCD, Kustomize.
- **Architecture:** "App of Apps" pattern.

## Directory Structure
- `/argocd`: Contains the `root-app.yaml`, which is the entry point for ArgoCD to manage the entire cluster state.
- `/apps/argocd-definitions`: Contains ArgoCD `Application` manifests that define each service and point to their source manifests.
- `/apps/<service-name>`: Contains the actual Kubernetes manifests (Deployment, Service, Ingress, PVC, etc.) and a `kustomization.yaml` for each service.

## Deployment and Management
The cluster is managed by applying the `root-app.yaml`. ArgoCD will then:
1. Sync all application definitions from `apps/argocd-definitions`.
2. Sync each individual application from its respective directory in `apps/`.

### Key Commands (Inferred)
As this is a manifest-only repository, most actions are performed via `kubectl` or the ArgoCD CLI/UI.

- **Apply Root Application:**
  ```bash
  kubectl apply -f argocd/root-app.yaml
  ```
- **Preview Kustomize Build:**
  ```bash
  kubectl kustomize apps/<service-name>
  ```

## Development Conventions
- **GitOps:** All changes to the cluster state should be made via commits to this repository.
- **Automated Sync:** Applications are configured with `automated` sync policy, including `prune: true` and `selfHeal: true`.
- **Namespacing:** Each application must include a `namespace.yaml` file. The corresponding ArgoCD `Application` should also have `CreateNamespace=true` set for robust bootstrapping.
- **Networking (Tailscale):** Services should be exposed via Ingress using `ingressClassName: tailscale` and the `tailscale.com/hostname` annotation to define their private DNS name.
- **Permissions:** For containers requiring persistent storage, prefer running with `USER_UID: "1000"` and `USER_GID: "1000"` to ensure consistent volume permissions across the cluster.
- **Service Selection:** Favor lightweight, Go-based, or container-native applications (e.g., Forgejo, Vaultwarden, AdGuard Home) to minimize resource footprint.
- **Vaultwarden Backups:** `vaultwarden` includes a `cronjob.yaml` for database backups.
