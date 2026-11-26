#!/usr/bin/env bash
set -Eeuo pipefail
node_ip=$1
[[ $node_ip =~ ^10\.10\.0\.(10|11|12)$ ]] || exit 2
exec > >(tee -a /var/log/cks-provision.log) 2>&1
trap 'echo "CKS provisioning failed at line $LINENO: $BASH_COMMAND" >&2' ERR
export DEBIAN_FRONTEND=noninteractive
swapoff -a
sed -i.bak -E '/^[^#].*[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab
modprobe overlay
modprobe br_netfilter
sysctl --system
apt-get update
apt-get install -y ca-certificates curl gnupg apt-transport-https containerd apparmor apparmor-utils auditd jq git vim tar gzip unzip tcpdump iproute2 iptables nftables procps util-linux findutils dnsutils iputils-ping openssl strace lsof libseccomp2
CRICTL_VERSION="v1.36.0"
ARCH="$(dpkg --print-architecture)"
curl -fsSLo /tmp/crictl.tar.gz "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz"
tar -xzf /tmp/crictl.tar.gz -C /usr/local/bin crictl
chmod 755 /usr/local/bin/crictl
rm /tmp/crictl.tar.gz
crictl --version
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl enable --now containerd
systemctl restart containerd
install -m 0755 -d /etc/apt/keyrings
curl -fsSL 'https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key' | gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
apt-get update
# Keep the image's existing dpkg configuration non-interactively.
apt-get install -y -o Dpkg::Options::="--force-confold" kubelet kubeadm kubectl
# Write kubelet overrides only after dpkg has installed its conffiles.
printf '%s\n' "KUBELET_EXTRA_ARGS=\"--node-ip=$node_ip\"" > /etc/default/kubelet
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
systemctl enable --now apparmor
systemctl enable --now auditd
mkdir -p /var/lib/kubelet/seccomp/profiles /etc/apparmor.d /opt/cks/logs
install -d -m 0755 /var/lib/cka/volumes/local-data
cp /opt/cks/policies/04-seccomp-deny-chmod.json /var/lib/kubelet/seccomp/profiles/cks-deny-chmod.json
cp /opt/cks/policies/05-apparmor-profile /etc/apparmor.d/cks-deny-write
apparmor_parser -r /etc/apparmor.d/cks-deny-write
# Falco is mandatory for the runtime-security exercises.
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
chmod 0644 /usr/share/keyrings/falco-archive-keyring.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main' > /etc/apt/sources.list.d/falcosecurity.list
apt-get update
FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf FALCOCTL_ENABLED=no apt-get install -y -o Dpkg::Options::="--force-confold" falco
# Preserve the exercise rules and load them alongside Falco's default rules.
touch /etc/falco/falco_rules.local.yaml
# Leave Falco local rules empty for the student to solve.
# A separate training directory contains only scenario data.
systemctl daemon-reload
systemctl enable --now falco-modern-bpf.service
systemctl is-active --quiet falco-modern-bpf.service
command -v falco
falco --version
# Helm CLI on the control-plane node for CKA exercises.
if [[ $(hostname -s) == k8s-control-1 ]]; then
  HELM_VERSION=v3.19.0
  HELM_SHA256=a7f81ce08007091b86d8bd696eb4d86b8d0f2e1b9f6c714be62f82f96a594496
  if curl --retry 3 -fsSLo /tmp/helm.tar.gz "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz" && printf '%s  %s\n' "$HELM_SHA256" /tmp/helm.tar.gz | sha256sum -c -; then
    tar -xzf /tmp/helm.tar.gz -C /tmp
    install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm
    helm version --short
  else
    echo 'WARNING: Helm could not be installed; core cluster setup continues.' >&2
  fi
  rm -rf /tmp/linux-amd64 /tmp/helm.tar.gz
fi
# Install Trivy
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --batch --yes --dearmor -o /usr/share/keyrings/trivy.gpg
chmod 0644 /usr/share/keyrings/trivy.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main' > /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install -y trivy
trivy --version
# Install Cosign
curl -fsSL https://github.com/sigstore/cosign/releases/download/v3.1.4/cosign-linux-amd64 -o /usr/local/bin/cosign
chmod 755 /usr/local/bin/cosign
cosign version
systemctl daemon-reload
touch /var/lib/cks-node-install.complete
echo 'CKS node provisioning completed.'
