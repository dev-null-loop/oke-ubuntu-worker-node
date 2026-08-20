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

variable "ubuntu_release" {
  type    = string
  default = "24.04"
}

variable "optimization_profile" {
  type    = string
  default = "fast-start"
}

variable "base_os" {
  type    = string
  default = "ubuntu"
}

variable "image_name" {
  type    = string
  default = "ubuntu-24.04-{{timestamp}}-OKE"
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

variable "ssh_private_key_file" {
  type    = string
  default = ""
}

variable "ssh_public_key_file" {
  type    = string
  default = ""
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

variable "install_helper_packages" {
  type    = bool
  default = true
}

variable "helper_packages" {
  type    = list(string)
  default = ["jq", "curl", "crictl"]
}

variable "enable_image_prepull" {
  type    = bool
  default = true
}

variable "prepull_failure_fatal" {
  type    = bool
  default = false
}

variable "enable_boot_cri_runtime" {
  type    = bool
  default = true
}

variable "enable_default_oke_prepull" {
  type    = bool
  default = true
}

variable "ocir_region" {
  type    = string
  default = ""
}

variable "oke_system_image_namespace" {
  type    = string
  default = ""
}

variable "oke_aux_image_namespace" {
  type    = string
  default = ""
}

variable "oke_vcn_native_ip_cni_tag" {
  type    = string
  default = ""
}

variable "oke_cloud_provider_oci_tag" {
  type    = string
  default = ""
}

variable "oke_proxymux_cli_tag" {
  type    = string
  default = ""
}

variable "oke_kube_proxy_image_ref" {
  type    = string
  default = ""
}

variable "oke_pause_image_ref" {
  type    = string
  default = ""
}

variable "prepull_images" {
  type    = list(string)
  default = []
}
