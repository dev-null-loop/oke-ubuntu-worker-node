# oke-ubuntu-worker-node

Build an OCI custom image for OKE Ubuntu worker nodes with Packer.

## Build

Use `packer/dev.pkrvars.hcl` with at least:
- `availability_domain`
- `compartment_ocid`
- `subnet_ocid`
- `base_image_ocid`
- `apt_source_url`
- `oke_package_name`
- `k8s_version`

Run:

```bash
cd packer
packer init .
packer build -var-file=dev.pkrvars.hcl .
```

## Defaults

- Ubuntu Noble (`24.04`)
- image metadata tags for `k8s_version`, base image, package, and profile
- helper packages baked in: `jq`, `curl`, `crictl`
- default OKE hot-path image pre-pull enabled
- CRI runtime enabled for earlier boot-time startup
- CNI host paths pre-created in the image
- bootstrap timing monitor enabled

## Fast Start

- Default OKE pre-pull covers:
  - `oke-public-vcn-native-ip-cni-plugin`
  - `oke-public-cloud-provider-oci`
  - `oke-public-proxymux-cli`
  - optional explicit refs for digest-pinned images such as `kube-proxy` or `pause`
- Recommended extra pre-pull for the current KPO startup-taint workaround:
  - `public.ecr.aws/z2c7x8q5/bitnami/kubectl@sha256:78726c39c86a468752790cd392839cef1282095400bb3cdf3619ab5dae9c8d2c`
- Add any extra first-pod-path images through `prepull_images`.
- Timing lands in `/var/log/oke-optimized-bootstrap-timing.log`.
- The repo can optimize image contents and image-time pulls. It cannot by itself remove Karpenter-side orchestration delays such as external startup-taint helpers.

## Files

- `packer/image.pkr.hcl`: OCI Packer build
- `packer/variables.pkr.hcl`: input variables
- `packer/dev.pkrvars.hcl.example`: example values
- `packer/dev.pkrvars.fast-start.example`: fast-start example values
- `scripts/install-oke-node-packages.sh`: installs OKE Ubuntu packages into the image
- `cloud-init/managed-minimal.yaml`: managed node bootstrap
- `cloud-init/self-managed-minimal.yaml`: self-managed node bootstrap
