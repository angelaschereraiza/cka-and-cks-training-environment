#!/usr/bin/env bash
set -euo pipefail

KEY="$1"
CONTROL="$2"
WORKER1="$3"
WORKER2="$4"
SSH=(-i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

run() {
  local host="$1"
  shift
  ssh "${SSH[@]}" "root@$host" "$@"
}

wait_ssh() {
  until run "$1" true 2>/dev/null; do sleep 5; done
}

for host in "$CONTROL" "$WORKER1" "$WORKER2"; do
  wait_ssh "$host"
  run "$host" "cloud-init status --wait"
done

run "$CONTROL" 'until ip -4 addr | grep -q "10.10.0.10/"; do sleep 2; done'
run "$WORKER1" 'until ip -4 addr | grep -q "10.10.0.11/"; do sleep 2; done'
run "$WORKER2" 'until ip -4 addr | grep -q "10.10.0.12/"; do sleep 2; done'

run "$CONTROL" 'kubeadm init --apiserver-advertise-address=10.10.0.10 --pod-network-cidr=10.244.0.0/16'
run "$CONTROL" 'mkdir -p /root/.kube && cp /etc/kubernetes/admin.conf /root/.kube/config && chmod 600 /root/.kube/config'

run "$CONTROL" '
  CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  ARCH=amd64
  [ "$(uname -m)" = "aarch64" ] && ARCH=arm64
  curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz"{,.sha256sum}
  sha256sum --check "cilium-linux-${ARCH}.tar.gz.sha256sum"
  tar xzvf "cilium-linux-${ARCH}.tar.gz" -C /usr/local/bin
  rm "cilium-linux-${ARCH}.tar.gz" "cilium-linux-${ARCH}.tar.gz.sha256sum"
  cilium install 1.20.2
'

JOIN=$(run "$CONTROL" 'kubeadm token create --print-join-command')
run "$WORKER1" "$JOIN"
run "$WORKER2" "$JOIN"

run "$CONTROL" 'cilium status --wait'
run "$CONTROL" 'kubectl wait --for=condition=Ready nodes --all --timeout=5m'
run "$CONTROL" 'kubectl get nodes -o wide'
