# CKA and CKS Training Environment

Disposable Kubernetes cluster for hands-on CKA and CKS practice.

Terraform creates three Fedora nodes on a private network. Cloud-init installs the node prerequisites, then Terraform bootstraps Kubernetes with kubeadm and Cilium.

## Cluster

| Node | Private IP |
| --- | --- |
| k8s-control-1 | 10.10.0.10 |
| k8s-worker-1 | 10.10.0.11 |
| k8s-worker-2 | 10.10.0.12 |

## Requirements

- Terraform
- SSH
- A configured cloud API token
- An SSH key registered with the cloud provider

Create `terraform.tfvars` from the example and set your SSH key values.

## Usage

```bash
terraform init
terraform apply
```

Destroy the environment with:

```bash
terraform destroy
```

`terraform.tfvars` and Terraform state files are excluded from Git.
