# CLAUDE.md — homelab

GitOps infrastructure for Kubernetes cluster `n8s`.

**Stack:** Kubernetes, ArgoCD, Kustomize, Tailscale ingress, Sealed Secrets

## Commands

```bash
kubectl apply -f argocd/root-app.yaml   # Bootstrap ArgoCD app-of-apps
kubectl kustomize apps/<service-name>   # Preview kustomize output
```

## Architecture

"App of Apps" pattern:

- `argocd/root-app.yaml` — root ArgoCD Application; syncs from `apps/argocd-definitions/`
- `apps/argocd-definitions/` — one ArgoCD `Application` manifest per service
- `apps/<service-name>/` — Kubernetes manifests (Deployment, Service, Ingress, PVC, etc.) + `kustomization.yaml`

## Key conventions

- All cluster changes via git commits (GitOps); auto-sync with `prune: true` and `selfHeal: true`
- Services exposed via `ingressClassName: tailscale` with `tailscale.com/hostname` annotation
- Persistent storage containers use `USER_UID: "1000"` / `USER_GID: "1000"` for volume permissions
- Each service needs a `namespace.yaml` and ArgoCD `Application` with `CreateNamespace=true`
- **Verify before changing:** Always confirm Secret keys, Service names, and Namespace names via `kubectl get` or grep before making manifest changes — do not assume naming conventions
- Check `git remote -v` before updating ArgoCD repo URLs
