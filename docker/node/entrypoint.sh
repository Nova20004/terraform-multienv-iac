#!/bin/bash
# Injects the operator's public key at container start. The key is never
# copied into an image layer. systemd (CMD) is exec'd so it remains PID 1.
set -euo pipefail

user="${SSH_USER:-ansible}"

if [[ ! "${user}" =~ ^[a-z][a-z0-9-]{0,30}$ ]]; then
  echo "SSH_USER must match ^[a-z][a-z0-9-]{0,30}$" >&2
  exit 1
fi

if [[ -z "${SSH_PUBLIC_KEY:-}" ]]; then
  echo "SSH_PUBLIC_KEY is empty. Refusing to boot a node nobody can log into." >&2
  exit 1
fi

if [[ ! -s /etc/machine-id ]]; then
  systemd-machine-id-setup
fi

if ! id "${user}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --groups sudo "${user}"
fi

install -d -m 700 -o "${user}" -g "${user}" "/home/${user}/.ssh"
printf '%s\n' "${SSH_PUBLIC_KEY}" > "/home/${user}/.ssh/authorized_keys"
chown "${user}:${user}" "/home/${user}/.ssh/authorized_keys"
chmod 600 "/home/${user}/.ssh/authorized_keys"

printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${user}" > /etc/sudoers.d/90-lab-user
chmod 440 /etc/sudoers.d/90-lab-user
visudo -cf /etc/sudoers.d/90-lab-user >/dev/null

mkdir -p /run/sshd
exec "$@"
