# oke-ubuntu-worker-node

Build an OCI custom image for OKE Ubuntu worker nodes with Packer.

## Build

1. In `packer/dev.pkrvars.hcl`, set:
   - `availability_domain`
   - `compartment_ocid`
   - `subnet_ocid`
   - `base_image_ocid`
2. Run:

```bash
cd packer
packer init .
packer build -var-file=dev.pkrvars.hcl .
```

## Current example target

- Ubuntu: Noble (`24.04`)
- Kubernetes repo: `kubernetes-1.36`
- OKE package: `oci-oke-node-all-1.36.1`
- Shape: `VM.Standard.E5.Flex`

## Files

- `packer/image.pkr.hcl`: OCI Packer build
- `packer/variables.pkr.hcl`: input variables
- `packer/dev.pkrvars.hcl.example`: example values
- `scripts/install-oke-node-packages.sh`: installs OKE Ubuntu packages into the image
- `cloud-init/managed-minimal.yaml`: managed node bootstrap
- `cloud-init/self-managed-minimal.yaml`: self-managed node bootstrap
