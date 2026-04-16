# terraform-hcp-bootstrap

[← docs.vslice.net](https://docs.vslice.net){ .md-button }

Terraform configuration that bootstraps HashiCorp Cloud Platform resources and
HCP Terraform backend-state infrastructure.

## What it provisions

- **HCP project isolation** — dedicated `hcp_project` for resource scoping
- **Optional Vault cluster** — free-tier HCP Vault via `hcp_hvn` +
  `hcp_vault_cluster`
- **HCP Terraform workspaces** — backend-state-only workspaces with execution
  mode pinned to `local` (no remote runs)
- **Encrypted state snapshots** — `just snapshot-hcp-bootstrap-state` captures
  state and outputs encrypted with age + SOPS

## Quick start

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and set values.
2. Export `HCP_CLIENT_ID`, `HCP_CLIENT_SECRET`, and `TFE_TOKEN`.
3. Run Terraform:

```bash
terraform init
terraform plan
terraform apply
```

## Using this backend from other repos

Add a `cloud` block in the target project pointing at the workspace this repo
creates, then run `terraform init` to initialize state storage. Workspaces are
state-only — all plans and applies run locally.
