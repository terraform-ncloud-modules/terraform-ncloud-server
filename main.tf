data "ncloud_server_image" "server_image" {
  filter {
    name   = "product_name"
    values = [var.server_image_name]
  }
}

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
  subnet_no      = coalesce(var.subnet_id, one(data.ncloud_subnet.subnet.*.id))
  login_key_name = var.login_key_name

  server_image_product_code = data.ncloud_server_image.server_image.id
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
  for_each = toset(try(var.default_network_interface.access_control_groups, []))

  vpc_no     = one(data.ncloud_vpc.vpc.*.id)
  is_default = (each.key == "default" ? true : false)
  filter {
    name   = "name"
    values = [each.key == "default" ? "${var.vpc_name}-default-acg" : each.key]
  }
}

resource "ncloud_network_interface" "default_nic" {
  name                  = var.default_network_interface.name
  description           = var.default_network_interface.description
  subnet_no             = coalesce(var.subnet_id, one(data.ncloud_subnet.subnet.*.id))
  private_ip            = lookup(var.default_network_interface, "private_ip", "") != "" ? var.default_network_interface.private_ip : null
  access_control_groups = lookup(var.default_network_interface, "access_control_group_ids", values(data.ncloud_access_control_group.acgs).*.id)
}

resource "ncloud_public_ip" "public_ip" {
  count              = var.is_associate_public_ip ? 1 : 0
  server_instance_no = ncloud_server.server.id
}

resource "ncloud_block_storage" "additional_block_storages" {
  for_each = { for volume in var.additional_block_storages : volume.name => volume }

  name               = each.value.name
  description        = each.value.description
  disk_detail_type   = each.value.disk_type
  size               = each.value.size
  server_instance_no = ncloud_server.server.id
}
