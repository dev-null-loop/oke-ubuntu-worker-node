# Startup Optimization Status

Date: August 21, 2026

This repo is no longer a basic Ubuntu OKE image builder. It now builds an opinionated fast-start image for Karpenter/KPO worker-node testing.

## Current Behavior

- installs the Ubuntu OKE node package from the supplied OKE apt repository
- removes `unattended-upgrades`
- installs helper packages:
  - `jq`
  - `curl`
  - `crictl`
- enables the node runtime early
- pre-pulls the configured image set
- pre-seeds OCI CNI host assets when the OCI CNI image is in the pre-pull set
- installs the bootstrap timing monitor
- sanitizes guest state before image capture

Main implementation files:

- `packer/image.pkr.hcl`
- `packer/variables.pkr.hcl`
- `scripts/install-oke-node-packages.sh`
- `scripts/lib/common.sh`
- `scripts/lib/prepull.sh`
- `scripts/lib/timing-monitor.sh`

## Variable Contract

Stable repo defaults live in `packer/variables.pkr.hcl`.

Version-specific and environment-specific values belong in `dev.pkrvars.hcl`, using `packer/dev.pkrvars.hcl.example` as the canonical starting point.

Required local values:

- `availability_domain`
- `compartment_ocid`
- `subnet_ocid`
- `base_image_ocid`
- `oke_repo_par`
- `k8s_version`
- `oke_default_prepull_images`

Optional local values:

- `additional_prepull_images`
- `ssh_private_key_file`
- `ssh_public_key_file`

## Pre-pull Policy

- `oke_default_prepull_images` is version-specific data, not template logic
- refresh it from a fresh-node pull observation whenever `k8s_version` changes or OKE changes the first-node image set
- `additional_prepull_images` is only for workload-specific or workaround-specific extras

## Cloud-init Examples

- `cloud-init/managed-minimal.yaml`
- `cloud-init/self-managed-minimal.yaml`

These are compatibility examples only. They are not the main fast-start path for the current repo.

## Current Boundaries

This repo can optimize:

- image contents
- image-time package installation
- image-time pulls
- guest bootstrap measurement

This repo does not by itself solve:

- OCI instance launch floor
- OKE/KPO orchestration delays
- OCI native pod networking convergence after node registration
