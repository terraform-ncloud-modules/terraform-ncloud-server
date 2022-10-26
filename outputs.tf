
locals {
  server_out = merge(
    { for attr_k, attr_v in ncloud_server.server : attr_k => attr_v if
      (attr_k != "private_ip") &&
      # (attr_k != "network_interface") &&
      (attr_k != "access_control_group_configuration_no_list") &&
      (attr_k != "raid_type_name") &&
      (attr_k != "tag_list") &&
      (attr_k != "user_data") &&
      (attr_k != "port_forwarding_external_port") &&
      (attr_k != "port_forwarding_internal_port") &&
      (attr_k != "port_forwarding_public_ip")
    },
    { private_ip = ncloud_network_interface.default_nic.private_ip }
  )
}



output "server" {
  value = local.server_out
}

output "default_network_interface" {
  value = ncloud_network_interface.default_nic
}

output "additional_block_storages" {
  value = ncloud_block_storage.additional_block_storages
}
