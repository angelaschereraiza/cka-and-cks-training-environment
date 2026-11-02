# CKA and CKS training environment

Terraform provisions three Ubuntu 24.04 nodes (one control plane, two workers) with containerd, kubeadm, Cilium, AppArmor, Seccomp, Falco (modern eBPF), auditd and ten preloaded security exercises.

## Setup

1. Register your public SSH key with your cloud account.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and replace placeholders with your actual SSH key name, local key paths and trusted SSH source CIDR.
3. Export `HCLOUD_TOKEN` in your shell (do not commit it).
4. Run `terraform init`, `terraform validate`, `terraform plan`, then `terraform apply`.
5. SSH to the control-plane IP as `student`; use `kubectl` or alias `k`.

Exercises are installed under `/opt/cks/manifests/`; node security policies are under `/opt/cks/policies/`. Falco custom rule is installed in `/etc/falco/falco_rules.local.yaml` on each node. Check `sudo systemctl status falco-modern-bpf`.

## Existing servers

Changes to `cloud-init.yaml` do not rerun cloud-init on existing servers. Terraform may plan server replacement when `user_data` changes. Review `terraform plan` before applying, especially to preserve training progress.

## Notes

The lab is intentionally insecure in selected workloads for training. Keep SSH ingress restricted. The sample `terraform.tfvars.example` contains placeholders, not valid credentials.
