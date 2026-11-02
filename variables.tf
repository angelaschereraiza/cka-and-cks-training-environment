variable "server_type" {
  type = string
  default = "cx23"
}
variable "image" {
  type = string
  default = "ubuntu-24.04"
}
variable "location" {
  type = string
  default = "fsn1"
}
variable "ssh_key_name" {
  type = string
}
variable "ssh_private_key_path" {
  type = string
}
variable "ssh_public_key_path" {
  type = string
}
variable "ssh_allowed_cidrs" {
  type = list(string)
  default = ["0.0.0.0/0", "::/0"]
}
