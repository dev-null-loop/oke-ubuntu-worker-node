variable "availability_domain" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "subnet_ocid" {
  type = string
}

variable "base_image_ocid" {
  type = string
}

variable "apt_source_url" {
  type = string
}

variable "oke_package_name" {
  type = string
}

variable "k8s_version" {
  type = string
}

variable "image_name" {
  type    = string
  default = "oke-ubuntu-worker-node-{{timestamp}}"
}

variable "shape" {
  type    = string
  default = "VM.Standard.E5.Flex"
}

variable "shape_ocpus" {
  type    = number
  default = 1
}

variable "shape_memory_in_gbs" {
  type    = number
  default = 12
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "image_launch_mode" {
  type    = string
  default = "NATIVE"
}

variable "instance_options_are_legacy_imds_endpoints_disabled" {
  type    = bool
  default = true
}

variable "disable_unattended_upgrades" {
  type    = bool
  default = true
}
