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
    direction = "in"
    protocol  = "tcp"
    port      = "22"

    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "icmp"

    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
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
  for_each = local.nodes

  name        = each.key
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [var.ssh_key_name]

  firewall_ids = [
    hcloud_firewall.kubernetes.id
  ]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

resource "hcloud_server_network" "kubernetes" {
  for_each = local.nodes

  server_id  = hcloud_server.kubernetes[each.key].id
  network_id = hcloud_network.kubernetes.id
  ip         = each.value

  depends_on = [
    hcloud_network_subnet.kubernetes
  ]
}