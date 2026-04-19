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

3. Authenticate the CLI using one of:
   - `export TFE_TOKEN=...`
   - `terraform login`
4. Run `terraform init` in the target repo to migrate or initialize state.

This backend pattern is state storage only. Workspaces are pinned to `execution_mode = "local"`.

## Encrypted State Snapshots

Use the repo task below to save encrypted local state snapshots with the
existing YubiKey-backed `age` setup managed through `nix-config`:

```bash
just snapshot-hcp-bootstrap-state
```

To push local state files to the AWS ops bucket as a versioned backup layer,
run:

```bash
just backup-hcp-bootstrap-state
```

Backup wrapper behavior:

- checks for `terraform.tfstate` and `terraform.tfstate.backup`
- resolves `OPS_BUCKET_NAME` from env first, then Bitwarden `AWS Bootstrap Outputs`
  when `BW_SESSION` is available
- uploads with server-side encryption (AES256)
- uses deterministic object keys:
  `terraform/bootstrap-state/terraform-hcp-bootstrap/YYYY/MM/DD/<timestamp>/<host>/<file>`
- writes a `.sha256` companion object per uploaded state file

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

## Terraform Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_hcp"></a> [hcp](#requirement\_hcp) | ~> 0.111 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | ~> 0.76 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_hcp"></a> [hcp](#provider\_hcp) | 0.111.0 |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | 0.76.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [hcp_hvn.ezra](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/resources/hvn) | resource |
| [hcp_project.ezra](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/resources/project) | resource |
| [hcp_vault_cluster.ezra](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/resources/vault_cluster) | resource |
| [hcp_vault_cluster_admin_token.ezra](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/resources/vault_cluster_admin_token) | resource |
| [tfe_organization.backend_state](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/organization) | resource |
| [tfe_project.backend_state](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/project) | resource |
| [tfe_workspace.terraform_projects](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace) | resource |
| [tfe_workspace_settings.terraform_projects](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/workspace_settings) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_hcp_project"></a> [create\_hcp\_project](#input\_create\_hcp\_project) | Create an HCP project for Ezra bootstrap resources. | `bool` | `false` | no |
| <a name="input_create_hcp_vault_admin_token"></a> [create\_hcp\_vault\_admin\_token](#input\_create\_hcp\_vault\_admin\_token) | Generate and manage an HCP Vault admin token for bootstrap operations. | `bool` | `true` | no |
| <a name="input_create_tfe_organization"></a> [create\_tfe\_organization](#input\_create\_tfe\_organization) | Create the HCP Terraform organization. Set false to use an existing org. | `bool` | `false` | no |
| <a name="input_enable_hcp_vault"></a> [enable\_hcp\_vault](#input\_enable\_hcp\_vault) | Create an HCP Vault cluster and HVN in the Ezra HCP project. | `bool` | `true` | no |
| <a name="input_hcp_hvn_cidr_block"></a> [hcp\_hvn\_cidr\_block](#input\_hcp\_hvn\_cidr\_block) | CIDR block for the Ezra HVN. | `string` | `"172.25.16.0/20"` | no |
| <a name="input_hcp_hvn_cloud_provider"></a> [hcp\_hvn\_cloud\_provider](#input\_hcp\_hvn\_cloud\_provider) | Cloud provider for the Ezra HVN. | `string` | `"aws"` | no |
| <a name="input_hcp_hvn_id"></a> [hcp\_hvn\_id](#input\_hcp\_hvn\_id) | HCP HVN ID for the Ezra Vault deployment. | `string` | `"ezra-hvn"` | no |
| <a name="input_hcp_hvn_region"></a> [hcp\_hvn\_region](#input\_hcp\_hvn\_region) | Region for the Ezra HVN and Vault cluster. | `string` | `"us-east-1"` | no |
| <a name="input_hcp_project_description"></a> [hcp\_project\_description](#input\_hcp\_project\_description) | Description for the Ezra HCP project. | `string` | `"Bootstrap project for Ezra-managed HCP services"` | no |
| <a name="input_hcp_project_id"></a> [hcp\_project\_id](#input\_hcp\_project\_id) | Existing HCP project ID to use when create\_hcp\_project is false. | `string` | `null` | no |
| <a name="input_hcp_project_name"></a> [hcp\_project\_name](#input\_hcp\_project\_name) | Name for the Ezra HCP project. | `string` | `"ezra"` | no |
| <a name="input_hcp_vault_cluster_id"></a> [hcp\_vault\_cluster\_id](#input\_hcp\_vault\_cluster\_id) | HCP Vault cluster ID. | `string` | `"ezra-vault"` | no |
| <a name="input_hcp_vault_public_endpoint"></a> [hcp\_vault\_public\_endpoint](#input\_hcp\_vault\_public\_endpoint) | Enable public endpoint for the HCP Vault cluster. | `bool` | `true` | no |
| <a name="input_hcp_vault_tier"></a> [hcp\_vault\_tier](#input\_hcp\_vault\_tier) | HCP Vault tier. For free tier use dev. | `string` | `"dev"` | no |
| <a name="input_terraform_backend_workspace_names"></a> [terraform\_backend\_workspace\_names](#input\_terraform\_backend\_workspace\_names) | Workspace names to create for terraform-* repositories using backend state only. | `list(string)` | <pre>[<br/>  "terraform-cloudflare-api-token-bootstrap",<br/>  "terraform-cloudflare-docs-sites",<br/>  "terraform-hcp-bootstrap",<br/>  "terraform-vault-bootstrap"<br/>]</pre> | no |
| <a name="input_tfe_hostname"></a> [tfe\_hostname](#input\_tfe\_hostname) | HCP Terraform/TFE hostname. | `string` | `"app.terraform.io"` | no |
| <a name="input_tfe_organization_email"></a> [tfe\_organization\_email](#input\_tfe\_organization\_email) | Admin email for organization creation (required if create\_tfe\_organization is true). | `string` | `null` | no |
| <a name="input_tfe_organization_name"></a> [tfe\_organization\_name](#input\_tfe\_organization\_name) | HCP Terraform organization name for backend state workspaces. | `string` | `"karl-vanderslice-org"` | no |
| <a name="input_tfe_project_description"></a> [tfe\_project\_description](#input\_tfe\_project\_description) | Project description for backend-state-only workspaces. | `string` | `"Backend state workspaces for terraform-* repositories"` | no |
| <a name="input_tfe_project_name"></a> [tfe\_project\_name](#input\_tfe\_project\_name) | Project name for backend-state-only workspaces. | `string` | `"terraform-backend-state"` | no |
| <a name="input_tfe_project_tags"></a> [tfe\_project\_tags](#input\_tfe\_project\_tags) | Tags to apply to the backend-state project. | `map(string)` | <pre>{<br/>  "managed_by": "terraform",<br/>  "owner": "ezra",<br/>  "purpose": "backend-state"<br/>}</pre> | no |
| <a name="input_tfe_workspace_tag_names"></a> [tfe\_workspace\_tag\_names](#input\_tfe\_workspace\_tag\_names) | Tag names applied to each backend-state workspace. | `list(string)` | <pre>[<br/>  "backend-state",<br/>  "terraform",<br/>  "ezra"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_hcp_project_id"></a> [hcp\_project\_id](#output\_hcp\_project\_id) | HCP project ID used for Ezra resources. |
| <a name="output_hcp_vault_addr"></a> [hcp\_vault\_addr](#output\_hcp\_vault\_addr) | Vault address to use for bootstrap operations. |
| <a name="output_hcp_vault_admin_token"></a> [hcp\_vault\_admin\_token](#output\_hcp\_vault\_admin\_token) | Vault admin token generated by HCP for bootstrap operations. |
| <a name="output_hcp_vault_cluster_id"></a> [hcp\_vault\_cluster\_id](#output\_hcp\_vault\_cluster\_id) | HCP Vault cluster ID when enable\_hcp\_vault is true. |
| <a name="output_hcp_vault_public_endpoint_url"></a> [hcp\_vault\_public\_endpoint\_url](#output\_hcp\_vault\_public\_endpoint\_url) | Public Vault endpoint URL when available. |
| <a name="output_tfe_organization_name"></a> [tfe\_organization\_name](#output\_tfe\_organization\_name) | HCP Terraform organization used for backend-state resources. |
| <a name="output_tfe_project_id"></a> [tfe\_project\_id](#output\_tfe\_project\_id) | HCP Terraform project ID for backend-state workspaces. |
| <a name="output_tfe_workspace_ids"></a> [tfe\_workspace\_ids](#output\_tfe\_workspace\_ids) | Workspace IDs keyed by workspace name. |
<!-- END_TF_DOCS -->
