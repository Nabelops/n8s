# CLAUDE.md — forgejo-runner

## Architecture

Forgejo runner deployed as a single pod with two containers:
- **runner** — forgejo-runner daemon that polls for and executes CI jobs
- **dind** — Docker-in-Docker sidecar; runner connects to it via `tcp://localhost:2375`

## Key constraints

- DinD requires `privileged: true` — rootless DinD does not work on Talos (unprivileged containers cannot access `/dev/net/tun`)
- The namespace must have `pod-security.kubernetes.io/enforce: privileged` to allow the DinD sidecar
- Forgejo runner v12.x has no native Kubernetes executor; DinD is the only supported approach

## CI image builds

Use Kaniko instead of `docker build/push` in workflows:
- Run via `docker run gcr.io/kaniko-project/executor:latest` inside the job
- Write registry auth to `$GITHUB_WORKSPACE/.docker/config.json` and mount it into the Kaniko container
- Pass `--skip-tls-verify` for the Tailscale-hosted registry
