variable "name" {
  description = "(Required) See the description in the readme"
  type        = string
}

variable "description" {
  description = "(Optional) See the description in the readme"
  type        = string
  default     = ""
}


variable "vpc_name" {
  description = "(Required) See the description in the readme"
  type        = string
  default     = null
}

variable "subnet_name" {
  description = "(Optional) See the description in the readme"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "(Optional) See the description in the readme"
  type        = string
  default     = null
}

variable "fee_system_type_code" {
  description = "(Optional) See the description in the readme"
  type        = string
  default     = "MTRAT"
}

variable "login_key_name" {
  description = "(Required) See the description in the readme"
  type        = string
}

variable "init_script_id" {
  description = "(Optional) See the description in the readme"
  type        = string
  default     = null
}

variable "server_image_name" {
  description = "(Required) See the description in the readme"
  type        = string
  default     = null
}

variable "member_server_image_name" {
  description = "(Required) See the description in the readme"
  type        = string
  default     = null
}


variable "product_generation" {
  description = "(Required) See the description in the readme"
  type        = string
}

variable "product_type" {
  description = "(Required) See the description in the readme"
  type        = string
}

variable "product_name" {
  description = "(Required) See the description in the readme"
  type        = string
}

variable "is_associate_public_ip" {
  description = "See the description in the readme"
  type        = bool
  default     = false
}

variable "is_protect_server_termination" {
  description = "(Optional) See the description in the readme"
  type        = bool
  default     = false
}

variable "is_encrypted_base_block_storage_volume" {
  description = "(Optional) See the description in the readme"
  type        = bool
  default     = false
}

variable "default_network_interface" {
  description = "(Required) See the description in the readme"
  # type        = map(map(any))
}

variable "additional_network_interfaces" {
  description = "(Optional) See the description in the readme"
  type        = list(any)
  default     = null
}

variable "additional_block_storages" {
  description = "(Optional) See the description in the readme"
  type        = list(any)
  default     = null
}

