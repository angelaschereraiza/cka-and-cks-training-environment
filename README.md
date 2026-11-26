# CKA and CKS training environment

Terraform provisions three Ubuntu 24.04 nodes (one control plane, two workers) with containerd, kubeadm, Cilium, AppArmor, Seccomp, Falco (modern eBPF), auditd and CKA/CKS training resources.

## Architecture

- `main.tf`: Hetzner servers, private network, firewall and bootstrap invocation.
- `cloud-init.yaml`: minimal SSH user and basic node configuration only.
- `bootstrap-cluster.sh`: transfers the local repository sources over SSH, installs node tools, initializes Kubernetes, joins workers, installs Cilium and starts the training provisioning service.
- `scripts/`: node installation and lab provisioning scripts.
- `cka/` and `cks/`: editable manifests, fixtures, policies, Helm charts and Kustomize resources. These are copied to `/opt/cka` and `/opt/cks` respectively on all nodes.
- `systemd/`: training provisioning service, started explicitly after all nodes are Ready. It is not enabled at boot to avoid resetting exercises on reboot.

The local checkout is the source of truth. No GitHub credentials, public repository or Argo CD installation are required on the nodes. Terraform uses SSH to upload the files, avoiding the Hetzner 32 KiB user-data limit. Manifests are stored as plain files rather than embedded gzip/base64 strings.

## Setup

1. Register your public SSH key with your cloud account.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and replace placeholders with your actual SSH key name, local key paths and trusted SSH source CIDR.
3. Export `HCLOUD_TOKEN` in your shell (do not commit it).
4. Run `terraform init`, `terraform validate`, `terraform plan`, then `terraform apply` from the checkout. The local machine requires Bash, SSH and tar.
5. SSH to the control-plane IP as `student`; use `kubectl` or alias `k`.

Node installation logs: `/var/log/cks-provision.log`. Lab provisioning: `sudo journalctl -u cks-lab.service -b`. Extended CKA provisioning logs: `/var/log/cka-extended.log`. Check Falco with `sudo systemctl status falco-modern-bpf`.

## Existing servers and changes

Keep your original `terraform.tfvars`, Terraform state and `.git` directory. Changes to cloud-init can cause server replacement; review the plan before applying. The migration is intended for fresh nodes (including a failed initial apply where only network/firewall were created).

Changes to source files trigger the bootstrap again. It uploads source files (overwriting corresponding staged files), skips completed node installation and does not restart an already active lab service. It does not delete removed source files on existing nodes. On the control plane, `sudo systemctl restart cks-lab.service` explicitly reapplies fixtures and generates new OpenSSL training certificates; this can overwrite exercise progress and may not cleanly reset every modified Kubernetes resource. For a fully clean training environment, destroy and recreate the cluster after reviewing the plan. Changes to installed node tools or policies may also require a fresh cluster.

## Notes

The lab is intentionally insecure in selected workloads for training. Keep SSH ingress restricted. The sample `terraform.tfvars.example` contains placeholders, not valid credentials. Do not commit Terraform state, private SSH keys or tokens.
