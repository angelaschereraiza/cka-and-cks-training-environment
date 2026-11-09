#!/usr/bin/env bash
set -Eeuo pipefail
if (( $# != 10 )); then
  echo "Usage: $0 SSH_KEY CONTROL_IP WORKER1_IP WORKER2_IP CONTROL_PRIVATE_IP CONTROL_MAC WORKER1_PRIVATE_IP WORKER1_MAC WORKER2_PRIVATE_IP WORKER2_MAC" >&2
  exit 2
fi
KEY=$1; CONTROL=$2; WORKER1=$3; WORKER2=$4
CONTROL_PRIVATE_IP=$5; CONTROL_MAC=$6
WORKER1_PRIVATE_IP=$7; WORKER1_MAC=$8
WORKER2_PRIVATE_IP=$9; WORKER2_MAC=${10}
KNOWN_HOSTS=$(mktemp)
chmod 600 "$KNOWN_HOSTS"
trap 'rm -f "$KNOWN_HOSTS"' EXIT
SSH=(-i "$KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$KNOWN_HOSTS" -o GlobalKnownHostsFile=/dev/null -o UpdateHostKeys=no)
run() { local host=$1; shift; ssh "${SSH[@]}" "student@$host" "$@"; }
root() { local host=$1; shift; run "$host" "sudo -n bash -lc $(printf '%q' "$*")"; }
configure_private_network() {
  local host=$1 ip=$2 mac=$3
  [[ $ip =~ ^10\.10\.0\.(10|11|12)$ ]] || { echo "Invalid private IP: $ip" >&2; return 1; }
  [[ $mac =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || { echo "Invalid network MAC: $mac" >&2; return 1; }
  root "$host" "cat > /etc/netplan/60-hcloud-private-network.yaml <<'EOF'
network:
  version: 2
  ethernets:
    hcloud-private:
      match:
        macaddress: '$mac'
      dhcp4: true
      dhcp6: false
      optional: true
EOF
chmod 600 /etc/netplan/60-hcloud-private-network.yaml
netplan generate
netplan apply"
}
wait_for_private_ip() {
  local host=$1 expected=$2 attempt
  for ((attempt=1; attempt<=30; attempt++)); do
    if root "$host" "ip -4 -o addr show | grep -Fq 'inet $expected/'"; then return 0; fi
    sleep 2
  done
  echo "Private IP was not assigned on $host: $expected" >&2
  return 1
}
wait_for_api_from_node() {
  local host=$1 attempt
  for ((attempt=1; attempt<=30; attempt++)); do
    if root "$host" 'curl -kfsS --connect-timeout 3 --max-time 5 https://10.10.0.10:6443/readyz >/dev/null'; then return 0; fi
    sleep 2
  done
  echo "Kubernetes API is unreachable from $host at 10.10.0.10:6443" >&2
  return 1
}
wait_ssh() {
  local host=$1 attempt
  for ((attempt=1; attempt<=90; attempt++)); do
    if run "$host" true >/dev/null 2>&1; then return 0; fi
    sleep 5
  done
  echo "SSH unavailable: $host" >&2; return 1
}
for host in "$CONTROL" "$WORKER1" "$WORKER2"; do
  wait_ssh "$host"
  echo "Waiting for cloud-init: $host"
  root "$host" 'cloud-init status --wait' || { root "$host" 'tail -100 /var/log/cks-provision.log || true'; exit 1; }
  root "$host" 'test -f /var/log/cks-provision.log && command -v kubeadm && command -v crictl && systemctl is-active --quiet containerd && systemctl is-active --quiet falco-modern-bpf.service && test -f /etc/falco/falco_rules.local.yaml'
done
for entry in "$CONTROL:$CONTROL_PRIVATE_IP:$CONTROL_MAC" "$WORKER1:$WORKER1_PRIVATE_IP:$WORKER1_MAC" "$WORKER2:$WORKER2_PRIVATE_IP:$WORKER2_MAC"; do
  host=${entry%%:*}; network=${entry#*:}; expected=${network%%:*}; mac=${network#*:}
  configure_private_network "$host" "$expected" "$mac"
  wait_for_private_ip "$host" "$expected"
done
if ! root "$CONTROL" 'test -s /etc/kubernetes/admin.conf'; then
  root "$CONTROL" 'kubeadm init --apiserver-advertise-address=10.10.0.10 --pod-network-cidr=10.244.0.0/16'
fi
root "$CONTROL" 'install -d -m 0700 -o student -g student /home/student/.kube; cp /etc/kubernetes/admin.conf /home/student/.kube/config; chown student:student /home/student/.kube/config; chmod 600 /home/student/.kube/config'
for host in "$CONTROL" "$WORKER1" "$WORKER2"; do
  wait_for_api_from_node "$host"
done
if ! root "$CONTROL" 'kubectl --kubeconfig=/etc/kubernetes/admin.conf -n kube-system get ds cilium >/dev/null 2>&1'; then
  echo 'Installing Cilium...'
  root "$CONTROL" 'set -e; version=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt); arch=amd64; [ "$(uname -m)" = aarch64 ] && arch=arm64; cd /tmp; curl -fL -O "https://github.com/cilium/cilium-cli/releases/download/${version}/cilium-linux-${arch}.tar.gz"; curl -fL -O "https://github.com/cilium/cilium-cli/releases/download/${version}/cilium-linux-${arch}.tar.gz.sha256sum"; sha256sum --check "cilium-linux-${arch}.tar.gz.sha256sum"; tar xzf "cilium-linux-${arch}.tar.gz" -C /usr/local/bin; KUBECONFIG=/etc/kubernetes/admin.conf cilium install --set ipam.mode=kubernetes'
fi
JOIN=$(root "$CONTROL" 'kubeadm token create --print-join-command')
for worker in "$WORKER1" "$WORKER2"; do
  if root "$worker" 'test -f /etc/kubernetes/kubelet.conf'; then echo "Already joined: $worker"; else root "$worker" "$JOIN"; fi
done
root "$CONTROL" 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system rollout status ds/cilium --timeout=10m'
root "$CONTROL" 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --for=condition=Ready nodes --all --timeout=10m'
root "$CONTROL" 'systemctl start cks-lab.service && systemctl is-active cks-lab.service'
run "$CONTROL" 'kubectl get nodes -o wide; kubectl -n cks-falco-lab get pods -o wide; kubectl get pods -A'
echo 'CKS cluster bootstrap completed.'
