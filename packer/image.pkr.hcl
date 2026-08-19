packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = ">= 1.1.2"
    }
  }
}

source "oracle-oci" "oke-ubuntu" {
  availability_domain                                 = var.availability_domain
  compartment_ocid                                    = var.compartment_ocid
  base_image_ocid                                     = var.base_image_ocid
  image_name                                          = var.image_name
  tags                                                = {
    k8s_version = var.k8s_version
  }
  shape                                               = var.shape
  subnet_ocid                                         = var.subnet_ocid
  ssh_username                                        = var.ssh_username
  image_launch_mode                                   = var.image_launch_mode
  instance_options_are_legacy_imds_endpoints_disabled = var.instance_options_are_legacy_imds_endpoints_disabled
  skip_create_image                                   = false

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
    ]
    script = "../scripts/install-oke-node-packages.sh"
  }
}
