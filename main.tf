terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.52"
    }
  }
}

provider "hcloud" {}

resource "hcloud_network" "kubernetes" {
  name     = "kubernetes-training"
  ip_range = "10.10.0.0/16"
}
resource "hcloud_network_subnet" "kubernetes" {
  network_id   = hcloud_network.kubernetes.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.10.0.0/24"
}
resource "hcloud_firewall" "kubernetes" {
  name = "kubernetes-training"
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_cidrs
  }
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "any"
    source_ips = ["10.10.0.0/16"]
  }
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "any"
    source_ips = ["10.10.0.0/16"]
  }
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["10.10.0.0/16"]
  }
}
locals {
  nodes = {
    "k8s-control-1" = "10.10.0.10"
    "k8s-worker-1"  = "10.10.0.11"
    "k8s-worker-2"  = "10.10.0.12"
  }
}
resource "hcloud_server" "kubernetes" {
  for_each     = local.nodes
  name         = each.key
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [var.ssh_key_name]
  firewall_ids = [hcloud_firewall.kubernetes.id]
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    node_ip        = each.value
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
resource "hcloud_server_network" "kubernetes" {
  for_each   = local.nodes
  server_id  = hcloud_server.kubernetes[each.key].id
  network_id = hcloud_network.kubernetes.id
  ip         = each.value
  depends_on = [hcloud_network_subnet.kubernetes]
}
resource "terraform_data" "cluster_bootstrap" {
  triggers_replace = concat(
    [for name in sort(keys(local.nodes)) : hcloud_server.kubernetes[name].id],
    [for name in sort(keys(local.nodes)) : hcloud_server_network.kubernetes[name].mac_address],
    [filesha256("${path.module}/bootstrap-cluster.sh")]
  )
  depends_on = [hcloud_server_network.kubernetes, hcloud_firewall.kubernetes]
  provisioner "local-exec" {
    command = "${path.module}/bootstrap-cluster.sh '${pathexpand(var.ssh_private_key_path)}' '${hcloud_server.kubernetes["k8s-control-1"].ipv4_address}' '${hcloud_server.kubernetes["k8s-worker-1"].ipv4_address}' '${hcloud_server.kubernetes["k8s-worker-2"].ipv4_address}' '${local.nodes["k8s-control-1"]}' '${hcloud_server_network.kubernetes["k8s-control-1"].mac_address}' '${local.nodes["k8s-worker-1"]}' '${hcloud_server_network.kubernetes["k8s-worker-1"].mac_address}' '${local.nodes["k8s-worker-2"]}' '${hcloud_server_network.kubernetes["k8s-worker-2"].mac_address}'"
  }
}
output "servers" {
  value = { for name, node in hcloud_server.kubernetes : name => { ipv4 = node.ipv4_address, private_ip = local.nodes[name] } }
}
