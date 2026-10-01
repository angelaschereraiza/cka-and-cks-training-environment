variable "location" {
  description = "Cloud location"
  type        = string
  default     = "fsn1"
}

variable "server_type" {
  description = "Server type used for Kubernetes nodes"
  type        = string
  default     = "cx23"
}

variable "image" {
  description = "Operating system image"
  type        = string
  default     = "fedora-44"
}

variable "ssh_key_name" {
  description = "SSH key name"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the private SSH key used for cluster bootstrap"
  type        = string
}
