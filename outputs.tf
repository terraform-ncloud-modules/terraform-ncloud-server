output "server" {
  value = ncloud_server.server
}

output "default_nic" {
  value = ncloud_network_interface.default_nic
}

output "additional_block_storages" {
  value = ncloud_block_storage.additional_block_storages
}