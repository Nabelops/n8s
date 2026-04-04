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

Use the Docker CLI (`docker login` + `docker build` + `docker push`) in workflows — Kaniko is not needed here because DinD is already available.

Volume mounts (`-v`) do NOT work for sharing files between the runner and DinD: the runner and DinD are separate containers with separate filesystems. The DinD daemon cannot access paths under `$GITHUB_WORKSPACE`. Use `docker login --password-stdin` to authenticate; Docker will write the credential into the runner container's own config, which is used for subsequent `docker push` calls via the TCP socket.
