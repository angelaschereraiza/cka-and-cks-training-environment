#!/usr/bin/env bash
set -Eeuo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
exec > >(tee -a /var/log/cka-extended.log) 2>&1
trap 'echo "Extended lab provisioning failed at line $LINENO" >&2' ERR
kubectl wait --for=condition=Ready node/k8s-worker-1 node/k8s-worker-2 --timeout=10m
# Install tools matching the actual running etcd image.
etcd_image=$(kubectl -n kube-system get pod etcd-k8s-control-1 -o jsonpath='{.spec.containers[0].image}')
etcd_version=$(echo "$etcd_image" | sed -E 's/.*:v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
[[ $etcd_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
arch=$(dpkg --print-architecture)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
archive="etcd-v$etcd_version-linux-$arch.tar.gz"
curl --retry 3 -fsSLo "$work/$archive" "https://github.com/etcd-io/etcd/releases/download/v$etcd_version/$archive"
tar -xzf "$work/$archive" -C "$work"
install -m 0755 "$work/etcd-v$etcd_version-linux-$arch/etcdctl" /usr/local/bin/etcdctl
install -m 0755 "$work/etcd-v$etcd_version-linux-$arch/etcdutl" /usr/local/bin/etcdutl
etcdctl version
etcdutl version
# Lab-only kubelet TLS exception: kubeadm uses self-signed serving certificates by default.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml
if ! kubectl -n kube-system get deployment metrics-server -o json | jq -e '.spec.template.spec.containers[0].args | index("--kubelet-insecure-tls") != null' >/dev/null; then
  kubectl -n kube-system patch deployment metrics-server --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi
kubectl -n kube-system rollout status deployment/metrics-server --timeout=5m
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=5m
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io crd/gateways.gateway.networking.k8s.io crd/httproutes.gateway.networking.k8s.io --timeout=90s
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo update traefik
helm upgrade --install traefik traefik/traefik --version 34.5.0 --namespace traefik --create-namespace --values /opt/cka/addons/traefik-values.yaml --wait --timeout 5m
kubectl apply -f /opt/cka/extended/namespaces.yaml
kubectl apply -f /opt/cka/extended/workloads.yaml
kubectl apply -f /opt/cka/extended/storage.yaml
kubectl apply -f /opt/cka/extended/scheduling.yaml
kubectl apply -f /opt/cka/extended/network.yaml
# Stage configuration copies away from the live static Pod directory.
install -d /opt/cka/fixtures/control-plane
sed 's@/etc/kubernetes/controller-manager.conf@/etc/kubernetes/controller-manager-missing.conf@g' /etc/kubernetes/manifests/kube-controller-manager.yaml > /opt/cka/fixtures/control-plane/controller-manager.yaml
sed 's@/etc/kubernetes/pki/apiserver.crt@/etc/kubernetes/pki/apiserver-missing.crt@g' /etc/kubernetes/manifests/kube-apiserver.yaml > /opt/cka/fixtures/control-plane/apiserver.yaml
