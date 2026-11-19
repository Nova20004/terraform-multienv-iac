# compute

Builds `docker/node` and runs N Ubuntu 24.04 containers with systemd as PID 1.

Runtime flags, all set here rather than in the image:

- `cgroupns_mode = host` and a bind mount of `/sys/fs/cgroup`
- tmpfs on `/run`, `/run/lock` and `/tmp` (`/run/lock` is required by systemd and is not optional on cgroup v2)
- `NET_ADMIN` (the spec capability). Extra capabilities are opt-in.
- `init = false` so Docker does not inject tini in front of `/sbin/init`
- `STOPSIGNAL SIGRTMIN+3`
- SSH published on `127.0.0.1` only
- `SSH_PUBLIC_KEY` passed in the environment and written by `entrypoint.sh` before `exec /sbin/init`. The key is not a layer in the image.

`systemd_privileged` defaults to **false**. Privileged mode is lab-only. Turn it on only when this Docker host cannot boot systemd without it (some Docker Desktop and Colima cgroup v2 setups). The root module output `systemd_privileged` records the choice. Do not carry `privileged = true` into a cloud VM module.

`enable_lb` adds the official nginx image (explicit stable tag and digest) on the frontend network. Upstreams are rendered with `templatefile`. Dev leaves this off.

There is no Docker-in-Docker. A `docker` Ansible role would need the host socket and a privileged container, which this lab refuses.
