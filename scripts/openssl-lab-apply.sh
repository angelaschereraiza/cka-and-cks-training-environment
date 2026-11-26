#!/usr/bin/env bash
set -Eeuo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
umask 077
base=/opt/cka/fixtures/openssl
install -d -m 0700 -o student -g student "$base" /home/student/openssl
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj '/CN=Training Root CA' -keyout ca.key -out ca.crt -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign'
openssl req -new -newkey rsa:2048 -nodes -subj '/CN=tls-web.cka-openssl.svc' -keyout web.key -out web.csr
printf '%s\n' 'basicConstraints=CA:FALSE' 'keyUsage=digitalSignature,keyEncipherment' 'extendedKeyUsage=serverAuth' 'subjectAltName=DNS:tls-web.cka-openssl.svc,DNS:tls-web.cka-openssl.svc.cluster.local' > web.ext
openssl x509 -req -in web.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -extfile web.ext -out web.crt
openssl req -new -newkey rsa:2048 -nodes -subj '/CN=lab-client/O=training' -keyout client.key -out client.csr
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out alternate.key
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj '/CN=Other Root CA' -keyout other.key -out other.crt
printf 'Kubernetes OpenSSL training\n' > message.txt
openssl dgst -sha256 -sign web.key -out message.sig message.txt
for f in ca.crt web.crt web.key client.csr client.key alternate.key other.crt message.txt message.sig; do
  install -m 0600 -o student -g student "$f" "$base/$f"
done
kubectl create namespace cka-openssl --dry-run=client -o yaml | kubectl apply -f -
kubectl -n cka-openssl create secret tls web-tls --cert=web.crt --key=web.key --dry-run=client -o yaml | kubectl apply -f -
kubectl -n cka-openssl create configmap web-config --from-literal=default.conf='server { listen 443 ssl; server_name tls-web.cka-openssl.svc; ssl_certificate /tls/tls.crt; ssl_certificate_key /tls/tls.key; ssl_protocols TLSv1.2 TLSv1.3; location / { return 200 "openssl lab\n"; } }' --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f /opt/cka/fixtures/openssl-web.yaml
