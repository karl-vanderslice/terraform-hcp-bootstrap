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

## Encrypted State Snapshots

Use the repo task below to save encrypted local state snapshots with the
existing YubiKey-backed `age` setup managed through `nix-config`:

```bash
just snapshot-hcp-bootstrap-state
```

What this does:

- captures `terraform output -json` and `terraform state pull`
- compresses both files with `zstd`
- encrypts the compressed payloads with `sops` using `age` recipients
- writes artifacts under `artifacts/hcp-bootstrap-state/`
- keeps only the newest two snapshot generations
- removes raw and unencrypted compressed intermediates after encryption

Default recipient behavior:

- uses `~/.config/sops/age/yubikey.txt` by default
- this aligns with the existing `nix-config` SOPS/YubiKey workflow
- if the recipient file does not exist, run `sops-yubikey-init`
- if auto-detection cannot infer a recipient, set `STATE_SOPS_AGE_RECIPIENTS`

Defaults can be overridden via environment variables:

- `STATE_COMPRESSION_CODEC` (default: `zstd`)
- `STATE_COMPRESSION_LEVEL` (default: `19`)
- `STATE_AGE_RECIPIENT` or `STATE_AGE_RECIPIENT_FILE`
- `STATE_SOPS_AGE_RECIPIENTS` (explicit `age1...` recipient list)
- `STATE_SNAPSHOT_DIR`
- `STATE_SNAPSHOT_RETENTION` (default: `2`)

Snapshot files:

- `state-<UTC timestamp>.tfstate.zst.age`
- `outputs-<UTC timestamp>.json.zst.age`
- `snapshot-<UTC timestamp>.json`

Decryption examples:

```bash
sops --decrypt --input-type binary --output-type binary state-<timestamp>.tfstate.zst.age | zstd -d -o -
sops --decrypt --input-type binary --output-type binary outputs-<timestamp>.json.zst.age | zstd -d -o -
```

## Notes

- `create_tfe_organization` defaults to `false` because many accounts already have a shared org.
- `create_hcp_project` defaults to `false` to support service principals without org-admin permissions.
- Backend workspaces are configured with `execution_mode = "local"` and no VCS repo block, so they are state-backend-only.
- Start with `hcp_vault_tier = "dev"` for free tier.
