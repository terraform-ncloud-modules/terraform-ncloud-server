# Ncloud Server Terraform module

## Usage (Single Server)

### Module Declaration

`main.tf`
``` hcl
module "server" {
  source = "terraform-ncloud-modules/server/ncloud"

  name           = var.server.name
  description    = var.server.description
  subnet_id      = module.vpc.all_subnets[var.server.subnet_name].id    // see "subnet_id reference scenario" below
  login_key_name = var.server.login_key_name

  // see "image & product reference scenario" below
  server_image_name  = var.server.server_image_name
  product_generation = var.server.product_generation
  product_type       = var.server.product_type
  product_name       = var.server.product_name

  fee_system_type_code = lookup(var.server, "fee_system_type_code", null)
  # init_script_id = ncloud_init_script.init_script.id  // Uncomment if you need. See "init_script_id reference scenario" below

  is_associate_public_ip                 = lookup(var.server, "is_associate_public_ip", false)
  is_protect_server_termination          = lookup(var.server, "is_protect_server_termination", false)
  is_encrypted_base_block_storage_volume = lookup(var.server, "is_encrypted_base_block_storage_volume", false)

  default_network_interface = {
    name        = var.server.default_network_interface.name
    description = lookup(var.server.default_network_interface, "description", null)
    private_ip  = lookup(var.server.default_network_interface, "private_ip", null)

    // see "access_control_group_ids reference scenario" below
    access_control_group_ids = [for acg_name in var.server.default_network_interface.access_control_groups :
      acg_name == "default" ? module.vpc.vpc.default_access_control_group_no : module.vpc.access_control_groups[acg_name].id
    ]     
  }

  additional_block_storages = [for vol in lookup(var.server, "additional_block_storages", []) :
    {
      name        = vol.name
      description = lookup(vol, "description", null)
      disk_type   = lookup(vol, "disk_type", null)
      size        = vol.size
    }
  ]
}
```

### Variable Declaration

You can create `terraform.tfvars` and refer to the sample below to write variable specifications.

`terraform.tfvars`

#### Specification
``` hcl
server = {
  name           = string
  description    = string
  vpc_name       = string
  subnet_name    = string
  login_key_name = string

  server_image_name  = string               // "Image Name" on "terraform-ncloud-docs"
  product_generation = string               // "Gen" on "Server product" page on "terraform-ncloud-docs"
  product_type       = string               // "Type" on "Server product" page on "terraform-ncloud-docs"
  product_name       = string               // "Product Name" on "Server product" page on "terraform-ncloud-docs"

  fee_system_type_code = string             // MTRAT (default) | FXSUM
  init_script_name     = string

  is_associate_public_ip                 = bool   // false(default), can be true only when subnet is public subnet
  is_protect_server_termination          = bool   // fasle(default)
  is_encrypted_base_block_storage_volume = bool   // fasle(default)

  default_network_interface = {
    name                  = string
    description           = string
    private_ip            = string          // IP address (not CIDR)
    access_control_groups = list(string)
  }

  additional_block_storages = [
    {
      name        = string
      description = string
      disk_type   = string                  // SSD (default) | HDD
      size        = integer
    }
  ]
}
```

#### Example
``` hcl
server = {
  name           = "svr-sample-single"
  description    = "Sample single server"
  vpc_name       = "vpc-sample"
  subnet_name    = "sbn-sample-public-1"
  login_key_name = "key-sample"

  server_image_name  = "CentOS 7.8 (64-bit)"
  product_generation = "G2"
  product_type       = "High CPU"
  product_name       = "vCPU 2EA, Memory 4GB, [SSD]Disk 50GB"

  fee_system_type_code = "MTRAT"
  init_script_name     = "init-sample"

  is_associate_public_ip                 = true
  is_protect_server_termination          = false
  is_encrypted_base_block_storage_volume = false

  default_network_interface = {
    name                  = "nic-sample-single-default"
    description           = "default nic for svr-sample-single"
    private_ip            = ""
    access_control_groups = ["default", "acg-sample-public"]
  }

  additional_block_storages = [
    {
      name        = "vol-sample-single-extra"
      description = "extra volume for svr-sample-single"
      disk_type   = "SSD"
      size        = 20
    }
  ]
}

```

You also need to create `variable.tf` that is exactly same as below.

`variable.tf`
``` hcl
variable "server" {}
```


## Usage (Multiple Servers)

### Module Declaration

`main.tf`
``` hcl

// need to declare local.servers to flatten complex architecure of var.servers
locals {
  servers = flatten([for server in var.servers : [
    for index in range(server.count) : merge(
      { name = format("%s-%03d", server.name_prefix, index + server.start_index) },
      { for k, v in server : k => v if(k != "count" && k != "name_prefix" && k != "start_index" && k != "default_network_interface" && k != "additional_block_storages") },
      { default_network_interface = merge(
        { name = format("%s-%03d-%s", server.default_network_interface.name_prefix, index + server.start_index, server.default_network_interface.name_postfix) },
        { for k, v in server.default_network_interface : k => v if(k != "name_prefix" && k != "name_postfix") }
      ) },
      { additional_block_storages = [for vol in lookup(server, "additional_block_storages", [] : merge(
        { name = format("%s-%03d-%s", vol.name_prefix, index + server.start_index, vol.name_postfix) },
        { for k, v in vol : k => v if(k != "name_prefix" && k != "name_postfix") }
      )] }
  )]])
}

module "servers" {
  source = "terraform-ncloud-modules/server/ncloud"

  for_each = { for server in local.servers: server.name => server}

  name           = each.value.name
  description    = each.value.description
  subnet_id      = module.vpc.all_subnets[each.value.subnet_name].id
  login_key_name = each.value.login_key_name

  server_image_name  = each.value.server_image_name
  product_generation = each.value.product_generation
  product_type       = each.value.product_type
  product_name       = each.value.product_name

  fee_system_type_code = lookup(each.value, "fee_system_type_code", null)
  # init_script_id = ncloud_init_script.init_script.id  // Uncomment if you need. See "init_script_id reference scenario" below

  is_associate_public_ip                 = lookup(each.value, "is_associate_public_ip", false)
  is_protect_server_termination          = lookup(each.value, "is_protect_server_termination", false)
  is_encrypted_base_block_storage_volume = lookup(each.value, "is_encrypted_base_block_storage_volume", false)

  default_network_interface = {
    name        = each.value.default_network_interface.name
    description = lookup(each.value.default_network_interface, "description", null)
    private_ip  = lookup(each.value.default_network_interface, "private_ip", null)
    access_control_group_ids = [for acg_name in each.value.default_network_interface.access_control_groups :
      acg_name == "default" ? module.vpc.vpc.default_access_control_group_no : module.vpc.access_control_groups[acg_name].id
    ]     
  }

  additional_block_storages = [for vol in lookup(each.value, "additional_block_storages", []) :
    {
      name        = vol.name
      description = lookup(vol, "description", null)
      disk_type   = lookup(vol, "disk_type", null)
      size        = vol.size
    }
  ]
}

```

### Variable Declaration

You can create `terraform.tfvars` and refer to the sample below to write variable specifications.

`terraform.tfvars`

#### Specification
``` hcl
servers = [
  {
    // see count & start_index scenario below
    count          = integer
    start_index    = integer

    name_prefix    = string
    description    = string
    vpc_name       = string
    subnet_name    = string
    login_key_name = string

    server_image_name  = string               // "Image Name" on "terraform-ncloud-docs"
    product_generation = string               // "Gen" on "Server product" page on "terraform-ncloud-docs"
    product_type       = string               // "Type" on "Server product" page on "terraform-ncloud-docs"
    product_name       = string               // "Product Name" on "Server product" page on "terraform-ncloud-docs"

    fee_system_type_code = string             // MTRAT (default) | FXSUM
    init_script_name     = string

    is_associate_public_ip                 = bool   // false(default), can be true only when subnet is public subnet
    is_protect_server_termination          = bool   // fasle(default)
    is_encrypted_base_block_storage_volume = bool   // fasle(default)

    default_network_interface = {
      // see count & start_index scenario below
      name_prefix           = string
      name_postfix          = string
      description           = string
      private_ip            = string          // IP address (not CIDR)
      access_control_groups = list(string)
    }

    additional_block_storages = [
      {
        // see count & start_index scenario below
        name_prefix  = string
        name_postfix = string
        description  = string
        disk_type    = string                  // SSD (default) | HDD
        size         = integer
      }
    ]
  }
]
```

#### Example
``` hcl
servers = [
  {
    count          = 3
    start_index    = 1

    name_prefix    = "svr-sample-multiple"
    description    = "Sample multiple server"
    vpc_name       = "vpc-sample"
    subnet_name    = "sbn-sample-public-1"
    login_key_name = "key-sample"

    server_image_name  = "CentOS 7.8 (64-bit)"
    product_generation = "G2"
    product_type       = "High CPU"
    product_name       = "vCPU 2EA, Memory 4GB, [SSD]Disk 50GB"

    fee_system_type_code = "MTRAT"
    init_script_name     = "init-sample"

    is_associate_public_ip                 = true
    is_protect_server_termination          = false
    is_encrypted_base_block_storage_volume = false

    default_network_interface = {
      name_prefix           = "nic-sample-multiple"
      name_postfix          = "def"
      description           = "default nic for svr-sample-multiple"
      private_ip            = ""
      access_control_groups = ["default", "acg-sample-public"]
    }

    additional_block_storages = [
      {
        name_prefix  = "vol-sample-multiple"
        name_postfix = "extra"
        description  = "extra volume for svr-sample-multiple"
        disk_type    = "SSD"
        size         = 20
      }
    ]
  }
]
```

You also need to create `variable.tf` that is exactly same as below.

`variable.tf`
``` hcl
variable "servers" {}
```


## Scenarios

### subnet_id reference scenario (for single server module)

with single `VPC module` (terraform-ncloud-modules/vpc/ncloud)
``` hcl
//variable
subnet_name = "sbn-sample-public-1"

//module
subnet_id = module.vpc.all_subnets[var.server.subnet_name].id
```

with multiple `VPC module` (terraform-ncloud-modules/vpc/ncloud)
``` hcl
//variable
vpc_name    = "vpc-sample"
subnet_name = "sbn-sample-public-1"

//module
subnet_id = module.vpcs[var.server.vpc_name].all_subnets[var.server.subnet_name].id
```
or you can just type subnet_id manually
``` hcl
//variable
subnet_id = "53578"

//module
subnet_id = var.server.subnet_id
```

### image & product reference scenario (for single server module)

You can find out values for server image & product on [terraform-ncloud-docs](https://github.com/NaverCloudPlatform/terraform-ncloud-docs/blob/main/docs/server_image_product.md). You must `Copy & Paste` values exactly.

``` hcl
//variable
server_image_name  = "CentOS 7.8(64-bit)"   // "Image Name" on "terraform-ncloud-docs"
product_generation = "G2"                   // "Gen" on "Server product" page on "terraform-ncloud-docs"
product_type       = "High CPU"             // "Type" on "Server product" page on "terraform-ncloud-docs"
product_name       = "vCPU 2EA, Memory 4GB, [SSD]Disk 50GB"   // "Product Name" on "Server product" page on "terraform-ncloud-docs"
```

> Argument `member_server_image` is not supported with this module for now. It will be update soon.

#### access_control_group_ids reference scenario (of default_network_interface) (for single server module)

When you want to use only `default_access_control_group` created by VPC.
- with single `VPC module`
``` hcl
//module
access_control_group_ids = [module.vpc.vpc.default_access_control_group_no]
```
- with multiple `VPC module`
``` hcl
//variable
vpc_name = "vpc-sample"

// module
access_control_group_ids = [module.vpcs[var.server.vpc_name].vpc.default_access_control_group_no]
```

if you want to use `default_access_control_group` created by VPC with other ACGs, you must type `default` in the list.
- with single `VPC module`
- if you manage `ACG`s within `VPC module`
``` hcl
//variable
access_control_groups = ["default", "acg-sample-public"]

//module
access_control_group_ids = [for acg_name in var.server.default_network_interface.access_control_groups :
  acg_name == "default" ? module.vpc.vpc.default_access_control_group_no :
  module.vpc.access_control_groups[acg_name].id
]
```
- with multiple `VPC module`
- if you manage `ACG`s within `VPC module`
``` hcl
//variable
vpc_name                  = "vpc-sample"
default_network_interface = {
  access_control_groups = ["default", "acg-sample-public"]
}

//module
access_control_group_ids = [for acg_name in var.server.default_network_interface.access_control_groups :
  acg_name == "default" ? module.vpcs[var.server.vpc_name].vpc.default_access_control_group_no : 
  module.vpcs[var.server.vpc_name].access_control_groups[acg_name].id
]
```

- with single `VPC module`
- if you manage `ACG`s using `ACG module`
``` hcl
//variable
access_control_groups = ["default", "acg-sample-public"]

//module
access_control_group_ids = [for acg_name in var.server.default_network_interface.access_control_groups :
  acg_name == "default" ? module.vpc.vpc.default_access_control_group_no : 
  module.access_control_groups.access_control_groups[acg_name].id
]
```

- with multiple `VPC module`
- if you manage `ACG`s using `ACG module`
``` hcl
//variable
vpc_name                  = "vpc-sample"
default_network_interface = {
  access_control_groups = ["default", "acg-sample-public"]
}

//module
access_control_group_ids = [for acg_name in var.server.default_network_interface.access_control_groups :
  acg_name == "default" ? module.vpcs[var.server.vpc_name].vpc.default_access_control_group_no : 
  module.access_control_groups.access_control_groups[acg_name].id
]
```

- with single `VPC module`
- if you manage `ACG`s within `VPC module` and `ACG module` at the same time
``` hcl
//variable
access_control_groups = ["default", "acg-sample-public"]

//module
access_control_group_ids = [for acg_name in var.server.default_network_interface.access_control_groups :
      acg_name == "default" ? module.vpc.vpc.default_access_control_group_no :
      join("", [
        length(lookup(module.access_control_groups.access_control_groups, acg_name, "")) > 0 ? module.access_control_groups.access_control_groups[acg_name].id : "",
        length(lookup(module.vpc.access_control_groups, acg_name, "")) > 0 ? module.vpc.access_control_groups[acg_name].id : ""
      ])
    ]
```

- with multiple `VPC module`
- if you manage `ACG`s within `VPC module` and `ACG module` at the same time
``` hcl
//variable
vpc_name                  = "vpc-sample"
default_network_interface = {
  access_control_groups = ["default", "acg-sample-public"]
}

//module
access_control_group_ids = [for acg_name in var.server.default_network_interface.access_control_groups :
  acg_name == "default" ? module.vpcs[var.server.vpc_name].vpc.default_access_control_group_no : join("", [
    length(lookup(module.access_control_groups.access_control_groups, acg_name, "")) > 0 ? module.access_control_groups.access_control_groups[acg_name].id : "",
    length(lookup(module.vpcs[var.server.vpc_name].access_control_groups, acg_name, "")) > 0 ? module.vpcs[var.server.vpc_name].access_control_groups[acg_name].id : ""
  ])
]
```

or you can just type list of ACG IDs manually
``` hcl
//variable
access_control_group_ids = [ "63100", "63096" ]

//module
access_control_group_ids = var.server.default_network_interface.access_control_group_ids
```

### init_script_id reference scenario

To use `init_script`, you need to create `ncloud_init_script` via terraform outside of `Server module`. Or, you can just create on Console or API.
- single `init_script`
``` hcl
resource "ncloud_init_script" "init-script" {
  name = "init-sample"
  content = file("init-sample.sh")
}
```
- multiple `init_script`s
``` hcl
init_scripts = [
  {
    name    = "init-sample-01"
    content = file("init-sample-01.sh")
  },
  {
    name    = "init-sample-02"
    content = file("init-sample-02.sh")
  }
]

resource "ncloud_init_script" "init-scripts" {
  for_each = { for init_script in var.init_scripts: init_script.name => init_script }

  name    = each.value.name
  content = each.value.content
}
```

If you want to use one `init_script`.
``` hcl
//module
init_script_id = ncloud_init_script.init_script.id
```

If you want to specify one from multiple `init_script`s
``` hcl
//variable
init_script_name = "init-sample-01"

//module
init_script_id = (lookup(var.server, "init_script_name", "") != "" ?
  ncloud_init_script.init_scripts[var.server.init_script_name].id : null
)
```

or you can just type list of `init_script_id` manually
``` hcl
//variable
init_script_id = 20482

//module
init_script_id = var.server.init_script_id
```

### count & start_index scenario (Multiple Servers)
When you are using multiple `Server module`, you can use arguments below to create indexed instances.

If you set as below
``` hcl
count       = 3
start_index = 1    // if set this 2, it starts with 002 
```
then
- `server`
``` hcl
name_prefix = "svr-sample-multiple"
==> 
svr-sample-multiple-001
svr-sample-multiple-002
svr-sample-multiple-003
```
- `default_network_interface`
``` hcl
name_prefix = "nic-sample-multiple"
name_postfix = "def"
==>
nic-sample-multiple-001-def
nic-sample-multiple-002-def
nic-sample-multiple-003-def
```
- `additional_block_storages`
``` hcl
name_prefix = "vol-sample-multiple"
name_postfix = "extra"
==>
vol-sample-multiple-001-extra
vol-sample-multiple-002-extra
vol-sample-multiple-003-extra
```