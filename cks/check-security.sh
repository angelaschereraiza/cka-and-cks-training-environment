#!/usr/bin/env bash
set +e
hostname
kubelet --version
containerd --version
cat /sys/kernel/security/lsm
aa-status
systemctl is-active apparmor auditd containerd
