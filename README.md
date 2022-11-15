# Multiple Server Module

## **This version of the module requires Terraform version 1.3.0 or later.**

This document describes the Terraform module that creates multiple Ncloud Servers.

You can check below scenarios.

- [Variable Declaration](#variable-declaration)
- [Module Declaration](#module-declaration)
- [image & product reference scenario](#image--product-reference-scenario)
- [count & start_index reference scenario](#count--start_index-reference-scenario)


## Variable Declaration

### Structure : `variable.tf`

You need to create `variable.tf` and copy & paste the variable declaration below.

**You can change the variable name to whatever you want.**

``` hcl
variable "servers" {
  type = list(object({
    create_multiple = optional(bool, false)          // If true, create multiple servers with postfixes "-001", "-002"
    count           = optional(number, 1)            // Required when create_multiple = true
    start_index     = optional(number, 1)            // Required when create_multiple = true

    name_prefix          = string                    // Same as "name" if create_multiple = false
    description          = optional(string, "")
    vpc_name             = string
    subnet_name          = string
    login_key_name       = string
    init_script_id       = optional(string, null)
    fee_system_type_code = optional(string, "MTRAT") // MTRAT (default) | FXSUM

    server_image_name  = string                      // "Image Name" on "terraform-ncloud-docs"
    product_generation = string                      // "Gen" on "Server product" page on "terraform-ncloud-docs"
    product_type       = string                      // "Type" on "Server product" page on "terraform-ncloud-docs"
    product_name       = string                      // "Product Name" on "Server product" page on "terraform-ncloud-docs"

    is_associate_public_ip                 = optional(bool, false) // Can only be true if the subnet is a public subnet.
    is_protect_server_termination          = optional(bool, false)
    is_encrypted_base_block_storage_volume = optional(bool, false)

    default_network_interface = object({
      name_prefix           = string                 // "name" will be "${name_prefix}-${name_postfix}" if create_multiple = false
      name_postfix          = string
      description           = optional(string, "")
      private_ip            = optional(string, null)              // IP address (not CIDR)
      access_control_groups = optional(list(string), ["default"]) // default value is ["default"], "default" is the "default access control group".
    })

    additional_block_storages = optional(list(object({
      name_prefix  = string                          // "name" will be "${name_prefix}-${name_postfix}" if create_multiple = false
      name_postfix = string
      description  = optional(string, "")
      size         = number                          // Unit = GB
      disk_type    = optional(string, "SSD")         // SSD (default) | HDD
    })), [])
  }))
  default = []
}

```

### Example : `terraform.tfvars`

You can create a `terraform.tfvars` and refer to the sample below to write the variable specification you want.
File name can be `terraform.tfvars` or anything ending in `.auto.tfvars`

**It must exactly match the variable name above.**

``` hcl
servers = [
  {
    create_multiple = true
    count           = 2
    start_index     = 1

    name_prefix          = "svr-foo"
    description          = "foo server"
    vpc_name             = "vpc-foo"
    subnet_name          = "sbn-foo-public-1"
    login_key_name       = "key-workshop"
    fee_system_type_code = "MTRAT"

    server_image_name  = "CentOS 7.8 (64-bit)"
    product_generation = "G2"
    product_type       = "High CPU"
    product_name       = "vCPU 2EA, Memory 4GB, [SSD]Disk 50GB"

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
      name_prefix  = "nic-bar"
      name_postfix = "def"
      description  = "default nic for svr-bar"
    }
  }
]
```

## Module Declaration

### `main.tf`

Map your `Server variable name` to a `local Server variable`. `Server module` are created using `local Server variables`. This eliminates the need to change the variable name reference structure in the `Server module`.

``` hcl
locals {
  servers = var.servers
}
```

`Server module` is using `count` & `start_index` for server numbering. In order to simplify the list of variables in the server to be finally created, flattening should be done as shown below.

``` hcl
locals {
  flatten_servers = flatten([for server in local.servers :
    [
      for index in range(server.count) : merge(
        { name = join("", [server.name_prefix, server.create_multiple ? format("-%03d", index + server.start_index) : ""]) },
        { for attr_key, attr_val in server : attr_key => attr_val if(attr_key != "default_network_interface" && attr_key != "additional_block_storages") },
        { default_network_interface = merge(server.default_network_interface, { name = join("", [
          server.default_network_interface.name_prefix, server.create_multiple ? format("-%03d", index + server.start_index) : "", "-${server.default_network_interface.name_postfix}"]) })
        },
        { additional_block_storages = [for vol in server.additional_block_storages : merge(vol, { name = join("", [
          vol.name_prefix, server.create_multiple ? format("-%03d", index + server.start_index) : "", "-${vol.name_postfix}"]) })]
        }
      )
    ]
  ])
}

```

Then just copy & paste the module declaration below.

``` hcl

module "servers" {
  source = "terraform-ncloud-modules/server/ncloud"

  for_each = { for server in local.flatten_servers : server.name => server }

  name                 = each.value.name
  description          = each.value.description

  // you can use "vpc_name" & "subnet_name". Then module will find "subnet_id" from "DataSource: ncloud_subnet".
  vpc_name             = each.value.vpc_name
  subnet_name          = each.value.subnet_name
  // or use only "subnet_id" instead for inter-module reference structure.
  # subnet_id            = module.vpcs[each.value.vpc_name].subnets[each.value.subnet_name].id

  login_key_name       = each.value.login_key_name
  init_script_id       = each.value.init_script_id
  fee_system_type_code = each.value.fee_system_type_code

  server_image_name  = each.value.server_image_name
  product_generation = each.value.product_generation
  product_type       = each.value.product_type
  product_name       = each.value.product_name

  is_associate_public_ip                 = each.value.is_associate_public_ip
  is_protect_server_termination          = each.value.is_protect_server_termination
  is_encrypted_base_block_storage_volume = each.value.is_encrypted_base_block_storage_volume

  // you can use just "default_network_interface" variable as is.
  default_network_interface = each.value.default_network_interface
  // or add "access_control_group_ids" attribute to the value of the "default_network_interface" variable for inter-module reference structure.
  # default_network_interface = merge(each.value.default_network_interface, {
  #   access_control_group_ids = [for acg_name in each.value.default_network_interface.access_control_groups : module.vpcs[each.value.vpc_name].access_control_groups[acg_name].id]
  # })
  
  additional_block_storages = each.value.additional_block_storages
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
