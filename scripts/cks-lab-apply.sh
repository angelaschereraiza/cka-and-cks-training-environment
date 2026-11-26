#!/usr/bin/env bash
set -Eeuo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
until test -s "$KUBECONFIG"; do sleep 10; done
until kubectl --request-timeout=5s get nodes >/dev/null 2>&1; do sleep 10; done
until kubectl -n kube-system get ds cilium >/dev/null 2>&1; do sleep 10; done
kubectl -n kube-system rollout status ds/cilium --timeout=10m
kubectl apply -f /opt/cks/manifests/
kubectl apply -f /opt/cka/manifests/00-namespaces.yaml
kubectl label nodes k8s-worker-1 cka.lab/zone=west --overwrite
kubectl label nodes k8s-worker-2 cka.lab/zone=east --overwrite
kubectl apply -f /opt/cka/fixtures/crd/widgets.yaml
kubectl wait --for=condition=Established crd/widgets.lab.example.com --timeout=90s
kubectl apply -f /opt/cka/manifests/
# Stage broken control-plane and node configuration off the live manifest paths.
install -d /opt/cka/fixtures/control-plane /opt/cka/fixtures/kubelet
sed 's@/etc/kubernetes/scheduler.conf@/etc/kubernetes/missing-scheduler.conf@g' /etc/kubernetes/manifests/kube-scheduler.yaml > /opt/cka/fixtures/control-plane/kube-scheduler-broken.yaml
sed 's/cgroupDriver: systemd/cgroupDriver: invalid-driver/g' /var/lib/kubelet/config.yaml > /opt/cka/fixtures/kubelet/config-broken.yaml
/usr/local/sbin/openssl-lab-apply.sh
/usr/local/sbin/cka-extended-apply.sh
