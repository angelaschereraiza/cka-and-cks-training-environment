# CKA and CKS Training Environment

Personal Kubernetes training environment for preparing for the
**Certified Kubernetes Administrator (CKA)** and **Certified Kubernetes
Security Specialist (CKS)** certifications.

The infrastructure is provisioned with Terraform. Kubernetes itself is
installed and managed manually with `kubeadm` to provide hands-on
experience with cluster administration, troubleshooting and security.

## Architecture

``` text
Kubernetes Cluster
│
├── Private Network 10.10.0.0/16
│
├── k8s-control-1
│   └── 10.10.0.10
│
├── k8s-worker-1
│   └── 10.10.0.11
│
└── k8s-worker-2
    └── 10.10.0.12
```

The cluster consists of:

-   1 Kubernetes control plane node
-   2 Kubernetes worker nodes
-   containerd as container runtime
-   kubeadm for cluster bootstrapping
-   a CNI plugin for Kubernetes networking

## Goals

The environment is intended for hands-on training in areas covered by
the CKA and CKS exams.

Topics include:

-   Cluster installation with kubeadm
-   Kubernetes architecture
-   Workloads and scheduling
-   Services and networking
-   Storage
-   RBAC
-   Cluster upgrades
-   etcd backup and restore
-   Troubleshooting
-   NetworkPolicies
-   Pod Security Standards
-   SecurityContexts
-   Kubernetes API security
-   Runtime security
-   Cluster hardening

The environment may intentionally contain broken or insecure
configurations as part of training exercises.

## Repository Structure

``` text
cka-and-cks-training-environment/
├── README.md
├── .gitignore
└── terraform/
    ├── versions.tf
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars.example
```

Additional Kubernetes manifests and exercises can be added later.

## Requirements

-   Terraform
-   SSH
-   Cloud infrastructure
-   Cloud API credentials

## Credentials

Do not store API tokens, credentials or private SSH keys in this
repository.

Use environment variables or another secure credential management
mechanism when running Terraform.

## Create Infrastructure

``` bash
cd terraform

terraform init
terraform plan
terraform apply
```

## Destroy Infrastructure

The complete training environment can be removed with:

``` bash
terraform destroy
```

Always verify the Terraform plan before applying or destroying
infrastructure.

## Kubernetes Installation

Terraform only provisions the underlying infrastructure.

Kubernetes is intentionally installed manually using `kubeadm` so that
cluster creation and administration remain part of the training process.

## Disclaimer

This environment is intended for training purposes only and should not
be used as a production Kubernetes environment.
