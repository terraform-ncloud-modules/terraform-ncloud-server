data "ncloud_server_image" "server_image" {
  # count = var.server_image_name != null ? 1 : 0
  filter {
    name   = "product_name"
    values = [var.server_image_name]
  }
}

# data "ncloud_member_server_image" "member_server_image" {
#   count = var.member_server_image_name != null ? 1 : 0
#   filter {
#     name   = "product_name"
#     values = [var.member_server_image_name]
#   }
# }

locals {
  product_type = {
    "High CPU"      = "HICPU"
    "CPU Intensive" = "CPU"
    "High Memory"   = "HIMEM"
    "GPU"           = "GPU"
    "Standard"      = "STAND"
  }
}

data "ncloud_server_product" "server_product" {
  # server_image_product_code = one(data.ncloud_server_image.server_image.*.id)
  server_image_product_code = data.ncloud_server_image.server_image.id

  filter {
    name   = "generation_code"
    values = [upper(var.product_generation)]
  }
  filter {
    name   = "product_type"
    values = [local.product_type[var.product_type]]
  }
  filter {
    name   = "product_name"
    values = [var.product_name]
  }
}


data "ncloud_vpc" "vpc" {
  count = var.vpc_name != null ? 1 : 0

  filter {
    name   = "name"
    values = [var.vpc_name]
  }
}

data "ncloud_subnet" "subnet" {
  count = var.subnet_name != null ? 1 : 0

  vpc_no = one(data.ncloud_vpc.vpc.*.id)
  filter {
    name   = "name"
    values = [var.subnet_name]
  }
}


resource "ncloud_server" "server" {
  name           = var.name
  description    = var.description
  subnet_no      = var.subnet_id == null ? one(data.ncloud_subnet.subnet.*.id) : var.subnet_id
  login_key_name = var.login_key_name

  server_image_product_code = data.ncloud_server_image.server_image.id
  # server_image_product_code = one(data.ncloud_server_image.server_image.*.id)
  # member_server_image_no    = one(data.ncloud_member_server_image.member_server_image.*.id)
  server_product_code = data.ncloud_server_product.server_product.product_code

  network_interface {
    network_interface_no = ncloud_network_interface.default_nic.id
    order                = 0
  }

  fee_system_type_code = var.fee_system_type_code
  init_script_no       = var.init_script_id

  is_protect_server_termination          = var.is_protect_server_termination
  is_encrypted_base_block_storage_volume = var.is_encrypted_base_block_storage_volume
}

data "ncloud_access_control_group" "acgs" {
  for_each = toset(lookup(var.default_network_interface, "access_control_groups", []))

  vpc_no     = one(data.ncloud_vpc.vpc.*.id)
  is_default = (each.key == "default" ? true : false)
  filter {
    name   = "name"
    values = [each.key == "default" ? "${var.vpc_name}-default-acg" : each.key]
  }
}

locals {
  default_nic_acg_ids = [for acg_name in lookup(var.default_network_interface, "access_control_groups", []) : data.ncloud_access_control_group.acgs[acg_name].id]
}

resource "ncloud_network_interface" "default_nic" {
  name                  = var.default_network_interface.name
  description           = lookup(var.default_network_interface, "description", null)
  subnet_no             = var.subnet_id == null ? one(data.ncloud_subnet.subnet.*.id) : var.subnet_id
  private_ip            = lookup(var.default_network_interface, "private_ip", "") != "" ? var.default_network_interface.private_ip : null
  access_control_groups = lookup(var.default_network_interface, "access_control_group_ids", local.default_nic_acg_ids)
}

resource "ncloud_public_ip" "public_ip" {
  count              = var.is_associate_public_ip ? 1 : 0
  server_instance_no = ncloud_server.server.id
}

resource "ncloud_network_interface" "additional_nics" {
  for_each = { for nic in var.additional_network_interfaces : nic.name => nic }

  name                  = each.value.name
  description           = lookup(each.value, "description", null)
  subnet_no             = each.value.subnet_id
  private_ip            = lookup(each.value, "private_ip", "") != "" ? each.value.private_ip : null
  access_control_groups = each.value.access_control_group_ids
  server_instance_no    = ncloud_server.server.id
}

resource "ncloud_block_storage" "additional_block_storages" {
  for_each = { for volume in var.additional_block_storages : volume.name => volume }

  name               = each.value.name
  description        = lookup(each.value, "description", null)
  disk_detail_type   = lookup(each.value, "disk_type", "SSD")
  size               = each.value.size
  server_instance_no = ncloud_server.server.id
}
