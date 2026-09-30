output "servers" {
  value = {
    for name, server in hcloud_server.kubernetes :
    name => {
      ipv4       = server.ipv4_address
      private_ip = local.nodes[name]
    }
  }
}