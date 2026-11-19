# Lab node image: Ubuntu 24.04 with systemd as PID 1 so Ansible can use
# service, sshd and package modules the way it would on a VM.
#
# Base digest resolved 2026-11-19 from the multi-arch index of ubuntu:24.04.
# Override with --build-arg UBUNTU_IMAGE=... ; never use the floating tag alone
# and never use :latest.
ARG UBUNTU_IMAGE=ubuntu:24.04@sha256:73b999393d07f2bf65a40373778a44dc9a6d54ad7718d29247d8ff9413c4d6a8

FROM ${UBUNTU_IMAGE}

ARG PROJECT=lab
ARG ENVIRONMENT=dev
ARG OWNER=local

LABEL environment="${ENVIRONMENT}" \
      managed-by="terraform" \
      project="${PROJECT}" \
      owner="${OWNER}"

# systemd must be root to be PID 1. This image is a local lab stand-in for a
# VM, not a hardened application container. See the repository README.
ENV DEBIAN_FRONTEND=noninteractive \
    container=docker \
    LANG=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        dbus \
        sudo \
        openssh-server \
        python3 \
        python3-apt \
        ca-certificates \
        iproute2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin \
    && rm -f /etc/machine-id /var/lib/dbus/machine-id \
    && touch /etc/machine-id \
    && mkdir -p /var/lib/dbus \
    && ln -sf /etc/machine-id /var/lib/dbus/machine-id \
    && mkdir -p /etc/systemd/system/multi-user.target.wants \
    && ln -sf /lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service \
    && ln -sf /lib/systemd/system/multi-user.target /etc/systemd/system/default.target \
    && for unit in \
        systemd-udevd.service \
        systemd-udevd-kernel.socket \
        systemd-udevd-control.socket \
        systemd-resolved.service \
        systemd-timesyncd.service \
        apt-daily.service \
        apt-daily.timer \
        apt-daily-upgrade.service \
        apt-daily-upgrade.timer \
        console-getty.service \
        getty@tty1.service \
        systemd-machine-id-commit.service \
    ; do \
        ln -sf /dev/null "/etc/systemd/system/${unit}"; \
    done \
    && useradd --create-home --shell /bin/bash --groups sudo ansible \
    && printf 'ansible ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-ansible \
    && chmod 440 /etc/sudoers.d/90-ansible \
    && visudo -cf /etc/sudoers.d/90-ansible

COPY sshd-container.conf /etc/ssh/sshd_config.d/50-container.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 644 /etc/ssh/sshd_config.d/50-container.conf \
    && chmod 755 /usr/local/bin/entrypoint.sh

# /run is replaced by a tmpfs at runtime; the ssh unit creates RuntimeDirectory.
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=12 \
    CMD python3 -c "import socket; s=socket.create_connection(('127.0.0.1',22),3); s.close()"

STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/sbin/init"]
