variable "availability_domain" {
  type        = string
  description = "OCI availability domain used for the temporary build instance."
}

variable "compartment_ocid" {
  type        = string
  description = "OCI compartment that hosts the temporary build instance."
}

variable "subnet_ocid" {
  type        = string
  description = "Subnet used by the temporary build instance."
}

variable "base_image_ocid" {
  type        = string
  description = "Source Ubuntu image OCID used as the build base."
}

variable "oke_repo_par" {
  type        = string
  description = "PAR token used to construct the Ubuntu OKE package repository URL."
}

variable "k8s_version" {
  type        = string
  description = "Full Kubernetes version used to derive the OKE node package name."

  validation {
    condition     = can(regex("^1\\.[0-9]+\\.[0-9]+$", var.k8s_version))
    error_message = "Kubernetes version must look like 1.xx.yy."
  }
}

variable "ubuntu_release" {
  type        = string
  default     = "24.04"
  description = "Ubuntu release for naming and OKE package repository selection."

  validation {
    condition     = contains(["22.04", "24.04"], var.ubuntu_release)
    error_message = "Ubuntu release must be 22.04 or 24.04."
  }
}

variable "optimization_profile" {
  type        = string
  default     = "fast-start"
  description = "Profile suffix used in the generated image name and tags."
}

variable "shape" {
  type        = string
  default     = "VM.Standard.E5.Flex"
  description = "OCI shape used by the temporary build instance."
}

variable "shape_ocpus" {
  type        = number
  default     = 1
  description = "OCPU count for the temporary build instance when using a flex shape."
}

variable "shape_memory_in_gbs" {
  type        = number
  default     = 12
  description = "Memory in GB for the temporary build instance when using a flex shape."
}

variable "ssh_private_key_file" {
  type        = string
  default     = ""
  description = "Optional private key path for Packer SSH access."
}

variable "ssh_username" {
  type        = string
  default     = "ubuntu"
  description = "SSH username used to connect to the temporary build instance."
}

variable "ssh_public_key_file" {
  type        = string
  default     = ""
  description = "Optional public key path injected into the temporary build instance."
}

variable "image_launch_mode" {
  type        = string
  default     = "NATIVE"
  description = "OCI launch mode for the resulting image build instance."
}

variable "skip_create_image" {
  type        = bool
  default     = false
  description = "Set true only for dry-run build validation without image creation."
}

variable "oke_default_prepull_images" {
  type        = list(string)
  default     = []
  description = "Version-specific baseline image set to pre-pull on every fast-start build."
}

variable "additional_prepull_images" {
  type        = list(string)
  default     = []
  description = "Optional extra images for workload-specific or workaround-specific warm-up."
}
