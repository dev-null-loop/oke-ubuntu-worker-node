packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = ">= 1.1.2"
    }
  }
}

locals {
  default_oke_prepull_images = var.enable_default_oke_prepull ? compact([
    var.oke_system_image_namespace != "" && var.oke_vcn_native_ip_cni_tag != "" ? "${var.ocir_region}.ocir.io/${var.oke_system_image_namespace}/oke-public-vcn-native-ip-cni-plugin:${var.oke_vcn_native_ip_cni_tag}" : "",
    var.oke_system_image_namespace != "" && var.oke_cloud_provider_oci_tag != "" ? "${var.ocir_region}.ocir.io/${var.oke_system_image_namespace}/oke-public-cloud-provider-oci:${var.oke_cloud_provider_oci_tag}" : "",
    var.oke_aux_image_namespace != "" && var.oke_proxymux_cli_tag != "" ? "${var.ocir_region}.ocir.io/${var.oke_aux_image_namespace}/oke-public-proxymux-cli:${var.oke_proxymux_cli_tag}" : "",
    var.oke_kube_proxy_image_ref,
    var.oke_pause_image_ref,
  ]) : []
  prepull_images_effective = concat(local.default_oke_prepull_images, var.prepull_images)
  builder_metadata = var.ssh_public_key_file != "" ? {
    ssh_authorized_keys = trimspace(file(var.ssh_public_key_file))
  } : {}
}

source "oracle-oci" "oke-ubuntu" {
  availability_domain = var.availability_domain
  compartment_ocid    = var.compartment_ocid
  base_image_ocid     = var.base_image_ocid
  image_name          = var.image_name
  tags = {
    k8s_version          = var.k8s_version
    base_os              = var.base_os
    ubuntu_release       = var.ubuntu_release
    base_image_ocid      = var.base_image_ocid
    oke_package_name     = var.oke_package_name
    optimization_profile = var.optimization_profile
  }
  shape                                               = var.shape
  subnet_ocid                                         = var.subnet_ocid
  ssh_username                                        = var.ssh_username
  ssh_private_key_file                                = var.ssh_private_key_file != "" ? var.ssh_private_key_file : null
  image_launch_mode                                   = var.image_launch_mode
  instance_options_are_legacy_imds_endpoints_disabled = var.instance_options_are_legacy_imds_endpoints_disabled
  skip_create_image                                   = false
  metadata                                            = local.builder_metadata

  shape_config {
    ocpus         = var.shape_ocpus
    memory_in_gbs = var.shape_memory_in_gbs
  }
}

build {
  sources = ["source.oracle-oci.oke-ubuntu"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "APT_SOURCE_URL=${var.apt_source_url}",
      "OKE_PACKAGE_NAME=${var.oke_package_name}",
      "DISABLE_UNATTENDED_UPGRADES=${var.disable_unattended_upgrades}",
      "INSTALL_HELPER_PACKAGES=${var.install_helper_packages}",
      "HELPER_PACKAGES=${join(",", var.helper_packages)}",
      "ENABLE_IMAGE_PREPULL=${var.enable_image_prepull}",
      "PREPULL_FAILURE_FATAL=${var.prepull_failure_fatal}",
      "ENABLE_BOOT_CRI_RUNTIME=${var.enable_boot_cri_runtime}",
      "PREPULL_IMAGES=${join(",", local.prepull_images_effective)}",
    ]
    script = "../scripts/install-oke-node-packages.sh"
  }
}
