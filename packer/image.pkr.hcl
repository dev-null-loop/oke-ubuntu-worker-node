packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = ">= 1.1.2"
    }
  }
}

locals {
  ubuntu_codename = var.ubuntu_release == "22.04" ? "jammy" : "noble"
  ubuntu_release_tag = replace(var.ubuntu_release, ".", "-")
  kubernetes_parts = split(".", var.k8s_version)
  kubernetes_minor = "${local.kubernetes_parts[0]}.${local.kubernetes_parts[1]}"
  apt_source_url = "https://objectstorage.us-sanjose-1.oraclecloud.com/p/${var.oke_repo_par}/n/odx-oke/b/okn-repositories-private/o/prod/ubuntu-${local.ubuntu_codename}/kubernetes-${local.kubernetes_minor}"
  oke_package_name = "oci-oke-node-all-${var.k8s_version}"
  prepull_images_effective = compact(concat(var.oke_default_prepull_images, var.additional_prepull_images))

  builder_metadata = var.ssh_public_key_file != "" ? {
    ssh_authorized_keys = trimspace(file(var.ssh_public_key_file))
  } : {}
}

source "oracle-oci" "oke-ubuntu" {
  availability_domain = var.availability_domain
  base_image_ocid     = var.base_image_ocid
  compartment_ocid    = var.compartment_ocid
  image_name          = "ubuntu-${local.ubuntu_release_tag}-{{timestamp}}-OKE-${var.k8s_version}-${var.optimization_profile}"
  shape               = var.shape
  ssh_username        = var.ssh_username
  subnet_ocid         = var.subnet_ocid

  ssh_private_key_file = var.ssh_private_key_file != "" ? var.ssh_private_key_file : null
  image_launch_mode    = var.image_launch_mode
  instance_options_are_legacy_imds_endpoints_disabled = true
  skip_create_image = var.skip_create_image
  metadata          = local.builder_metadata

  tags = {
    k8s_version          = var.k8s_version
    base_os              = "ubuntu"
    ubuntu_release       = var.ubuntu_release
    base_image_ocid      = var.base_image_ocid
    oke_package_name     = local.oke_package_name
    optimization_profile = var.optimization_profile
  }

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
      "APT_SOURCE_URL=${local.apt_source_url}",
      "OKE_PACKAGE_NAME=${local.oke_package_name}",
      "PREPULL_IMAGES=${join(",", local.prepull_images_effective)}",
    ]
    script = "../scripts/install-oke-node-packages.sh"
  }
}
