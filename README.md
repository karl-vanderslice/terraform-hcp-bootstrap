# terraform-hcp-bootstrap

Bootstrap HCP and HCP Terraform resources:

- HCP project isolation (`hcp_project`) and optional free-tier Vault bootstrap (`hcp_hvn` + `hcp_vault_cluster`)
- HCP Terraform organization/project/workspaces for backend-state-only usage
- Workspace execution mode pinned to `local` via `tfe_workspace_settings` (no remote runs)

## Authentication

Use environment variables for provider auth:

- `HCP_CLIENT_ID`
- `HCP_CLIENT_SECRET`
- `TFE_TOKEN`

If your HCP service principal cannot create projects, set `create_hcp_project = false` (default) and either:

- allow provider-default project selection, or
- set `hcp_project_id` explicitly.

Optional provider environment variables:

- `TFE_HOSTNAME` (defaults to `app.terraform.io`)
- `HCP_PROJECT_ID` (only if you are not creating/selecting via Terraform inputs)

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and adjust values.
2. Export auth values.
3. Run Terraform:

```bash
terraform init
terraform plan
terraform apply
```

## Configure Other Terraform Projects To Use This Backend

1. Ensure the target workspace exists in HCP Terraform (this repo creates them
   for workspace names listed in `terraform_backend_workspace_names`).
2. In the target project, add a cloud backend block:

```hcl
terraform {
  cloud {
    organization = "your-org-name"

    workspaces {
      name = "your-workspace-name"
    }
  }
}
```

1. Authenticate the CLI using one of:
   - `export TFE_TOKEN=...`
   - `terraform login`
1. Run `terraform init` in the target repo to migrate or initialize state.

This backend pattern is state storage only. Workspaces are pinned to `execution_mode = "local"`.

## Notes

- `create_tfe_organization` defaults to `false` because many accounts already have a shared org.
- `create_hcp_project` defaults to `false` to support service principals without org-admin permissions.
- Backend workspaces are configured with `execution_mode = "local"` and no VCS repo block, so they are state-backend-only.
- Start with `hcp_vault_tier = "dev"` for free tier.
