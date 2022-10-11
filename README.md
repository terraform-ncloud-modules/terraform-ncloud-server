# Multiple VPC Module

This document describes the Terraform module that creates multiple Ncloud Servers.

Before use `Server module`, you need create `VPC module`.

- [VPC module](https://registry.terraform.io/modules/terraform-ncloud-modules/vpc/ncloud/latest)

Also, you can check below scenarios.

- [Variable Declaration](#variable-declaration)
- [Module Declaration](#module-declaration)
- [image & product reference scenario](#image--product-reference-scenario)
- [count & start_index reference scenario](#count--start_index-reference-scenario)


## Variable Declaration

### `variable.tf`

You need to create `variable.tf` and declare the VPC variable to recognize VPC variable in `terraform.tfvars`. You can change the variable name to whatever you want.

``` hcl
variable "servers" { default = [] }
```

### `terraform.tfvars`

You can create `terraform.tfvars` and refer to the sample below to write variable declarations.
File name can be `terraform.tfvars` or anything ending in `.auto.tfvars`

#### Structure

``` hcl
servers = [
  {
    create_multiple = bool             // (Required)
    count           = integer          // (Required when create_multiple = true)
    start_index     = integer          // (Required when create_multiple = true)

    name_prefix    = string            // (Required)
    description    = string            // (Optional)
    vpc_name       = string            // (Required)
    subnet_name    = string            // (Required)
    login_key_name = string            // (Required)

    server_image_name  = string        // (Required) "Image Name" on "terraform-ncloud-docs"
    product_generation = string        // (Required) "Gen" on "Server product" page on "terraform-ncloud-docs"
    product_type       = string        // (Required) "Type" on "Server product" page on "terraform-ncloud-docs"
    product_name       = string        // (Required) "Product Name" on "Server product" page on "terraform-ncloud-docs"

    fee_system_type_code = string      // (Optional), MTRAT (default) | FXSUM

    is_associate_public_ip                 = bool   // (Optional), false(default), can be true only when subnet is public subnet
    is_protect_server_termination          = bool   // (Optional), fasle(default)
    is_encrypted_base_block_storage_volume = bool   // (Optional), fasle(default)

    // (Required)
    default_network_interface = {             
      name_prefix           = string         // (Required) 
      name_postfix          = string         // (Required) 
      description           = string         // (Optional)
      private_ip            = string         // (Optional), IP address (not CIDR)
      access_control_groups = list(string)   // (Optional), default value is ["default"]
    }

    // (Optional)
    additional_block_storages = [            
      {
        name_prefix  = string                // (Required) 
        name_postfix = string                // (Required) 
        description  = string                // (Optional)
        size         = integer               // (Required), Unit = GB
        disk_type    = string                // (Optional), SSD (default) | HDD
      }
    ]
  }
]
```

#### Example

``` hcl
servers = [
  {
    create_multiple = true
    count           = 2
    start_index     = 1

    name_prefix    = "svr-foo"
    description    = "foo server"
    vpc_name       = "vpc-foo"
    subnet_name    = "sbn-foo-public-1"
    login_key_name = "key-workshop"

    server_image_name  = "CentOS 7.8 (64-bit)"
    product_generation = "G2"
    product_type       = "High CPU"
    product_name       = "vCPU 2EA, Memory 4GB, [SSD]Disk 50GB"

    fee_system_type_code = "MTRAT"

    is_associate_public_ip                 = true
    is_protect_server_termination          = false
    is_encrypted_base_block_storage_volume = false

    default_network_interface = {
      name_prefix           = "nic-foo"
      name_postfix          = "def"
      description           = "default nic for svr-foo"
      private_ip            = ""
      access_control_groups = ["default", "acg-foo-public"]
    }

    additional_block_storages = [
      {
        name_prefix  = "vol-foo"
        name_postfix = "extra"
        description  = "extra volume for svr-foo"
        disk_type    = "SSD"
        size         = 20
      }
    ]
  },
  {
    create_multiple = false

    name_prefix    = "svr-bar"
    description    = "bar server"
    vpc_name       = "vpc-bar"
    subnet_name    = "sbn-bar-public"
    login_key_name = "key-workshop"

    server_image_name  = "CentOS 7.8 (64-bit)"
    product_generation = "G2"
    product_type       = "High CPU"
    product_name       = "vCPU 2EA, Memory 4GB, [SSD]Disk 50GB"

    default_network_interface = {
      name_prefix           = "nic-bar"
      name_postfix          = "def"
      description           = "default nic for svr-bar"
    }
  }
]
```

## Module Declaration

### `main.tf`

Map your `Server variable name` to a `local Server variable`. `Server module` are created using `local Server variables`. This eliminates the need to change the variable name reference structure in the `Server module`.

Also, the `Server module` is designed to be used with `VPC module` together. So the `VPC module` must also be specified as a `local VPC module variable`.

``` hcl
locals {
  servers     = var.servers
  module_vpcs = module.vpcs
}
```

`Server module` is using `count` & `start_index` for server numbering. In order to simplify the list of variables in the server to be finally created, flattening should be done as shown below.

``` hcl
locals {
  flatten_servers = flatten([for server in local.servers : server.create_multiple ?
    [
      for index in range(server.count) : merge(
        { name = format("%s-%03d", server.name_prefix, index + server.start_index) },
        { for attr_key, attr_val in server : attr_key => attr_val if(attr_key != "default_network_interface" && attr_key != "additional_block_storages") },
        { default_network_interface = merge(server.default_network_interface,
          { name = format("%s-%03d-%s", server.default_network_interface.name_prefix, index + server.start_index, server.default_network_interface.name_postfix) })
        },
        { additional_block_storages = [for vol in lookup(server, "additional_block_storages", []) : merge(vol,
          { name = format("%s-%03d-%s", vol.name_prefix, index + server.start_index, vol.name_postfix) })]
        }
      )
    ] :
    [
      merge(
        { name = server.name_prefix },
        { for attr_key, attr_val in server : attr_key => attr_val if(attr_key != "default_network_interface" && attr_key != "additional_block_storages") },
        { default_network_interface = merge(server.default_network_interface,
          { name = format("%s-%s", server.default_network_interface.name_prefix, server.default_network_interface.name_postfix) })
        },
        { additional_block_storages = [for vol in lookup(server, "additional_block_storages", []) : merge(vol,
          { name = format("%s-%s", vol.name_prefix, vol.name_postfix) })]
        }
      )
    ]
  ])
}

```

Then just copy and paste the module declaration below.

``` hcl

module "servers" {
  source = "terraform-ncloud-modules/server/ncloud"

  for_each = { for server in local.flatten_servers : server.name => server }

  name           = each.value.name
  description    = each.value.description
  subnet_id      = local.module_vpcs[each.value.vpc_name].subnets[each.value.subnet_name].id
  login_key_name = each.value.login_key_name

  // It will implemented soon. Now you can just put init_script ID directly.
  // init_script_id = ""

  server_image_name  = each.value.server_image_name
  product_generation = each.value.product_generation
  product_type       = each.value.product_type
  product_name       = each.value.product_name

  fee_system_type_code = lookup(each.value, "fee_system_type_code", "MTRAT")

  is_associate_public_ip                 = lookup(each.value, "is_associate_public_ip", false)
  is_protect_server_termination          = lookup(each.value, "is_protect_server_termination", false)
  is_encrypted_base_block_storage_volume = lookup(each.value, "is_encrypted_base_block_storage_volume", false)

  default_network_interface = {
    name        = each.value.default_network_interface.name
    description = lookup(each.value.default_network_interface, "description", null)
    private_ip  = lookup(each.value.default_network_interface, "private_ip", null)
    access_control_group_ids = [for acg_name in lookup(each.value.default_network_interface, "access_control_groups", ["default"]) :
      acg_name == "default" ? local.module_vpcs[each.value.vpc_name].vpc.default_access_control_group_no : local.module_vpcs[each.value.vpc_name].access_control_groups[acg_name].id
    ]
  }

  additional_block_storages = [for vol in lookup(each.value, "additional_block_storages", []) :
    {
      name        = vol.name
      description = lookup(vol, "description", null)
      disk_type   = lookup(vol, "disk_type", "SSD")
      size        = vol.size
    }
  ]
}

```

## image & product reference scenario

You can find out values for server image & product on [terraform-ncloud-docs](https://github.com/NaverCloudPlatform/terraform-ncloud-docs/blob/main/docs/server_image_product.md). You must `Copy & Paste` values exactly.

``` hcl
//variable
server_image_name  = "CentOS 7.8(64-bit)"                     // "Image Name" on "terraform-ncloud-docs"
product_generation = "G2"                                     // "Gen" on "Server product" page on "terraform-ncloud-docs"
product_type       = "High CPU"                               // "Type" on "Server product" page on "terraform-ncloud-docs"
product_name       = "vCPU 2EA, Memory 4GB, [SSD]Disk 50GB"   // "Product Name" on "Server product" page on "terraform-ncloud-docs"
```

! Argument `member_server_image` is not supported with this module for now. It will be update soon.

## count & start_index reference scenario

#### create_multiple = true

If you set as below

``` hcl
create_multiple = true
count           = 3
start_index     = 1    // if set this 2, it starts with 002 
```

then

- `server`

``` hcl
name_prefix = "svr-foo"
==> 
names = [svr-foo-001, svr-foo-002, svr-foo-003]
```

- `default_network_interface`

``` hcl
name_prefix  = "nic-foo"
name_postfix = "def"
==>
names = [nic-foo-001-def, nic-foo-002-def, nic-foo-003-def]
```

- `additional_block_storages`

``` hcl
name_prefix  = "vol-foo"
name_postfix = "extra"
==>
names = [vol-foo-001-extra, vol-foo-002-extra, vol-foo-003-extra]
```

#### create_multiple = false

- `server`

``` hcl
name_prefix = "svr-bar"
==> 
name = svr-bar
```

- `default_network_interface`

``` hcl
name_prefix  = "nic-bar"
name_postfix = "def"
==>
name = nic-bar-def
```

- `additional_block_storages`

``` hcl
name_prefix  = "vol-bar"
name_postfix = "extra"
==>
name = vol-bar-extra
```