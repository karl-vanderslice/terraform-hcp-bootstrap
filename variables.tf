variable "create_hcp_project" {
  description = "Create an HCP project for Ezra bootstrap resources."
  type        = bool
  default     = false
}

variable "hcp_project_id" {
  description = "Existing HCP project ID to use when create_hcp_project is false."
  type        = string
  default     = null
}

variable "hcp_project_name" {
  description = "Name for the Ezra HCP project."
  type        = string
  default     = "ezra"
}

variable "hcp_project_description" {
  description = "Description for the Ezra HCP project."
  type        = string
  default     = "Bootstrap project for Ezra-managed HCP services"
}

variable "enable_hcp_vault" {
  description = "Create an HCP Vault cluster and HVN in the Ezra HCP project."
  type        = bool
  default     = true
}

variable "hcp_hvn_id" {
  description = "HCP HVN ID for the Ezra Vault deployment."
  type        = string
  default     = "ezra-hvn"
}

variable "hcp_hvn_cloud_provider" {
  description = "Cloud provider for the Ezra HVN."
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "azure", "gcp"], var.hcp_hvn_cloud_provider)
    error_message = "hcp_hvn_cloud_provider must be one of: aws, azure, gcp."
  }
}

variable "hcp_hvn_region" {
  description = "Region for the Ezra HVN and Vault cluster."
  type        = string
  default     = "us-east-1"
}

variable "hcp_hvn_cidr_block" {
  description = "CIDR block for the Ezra HVN."
  type        = string
  default     = "172.25.16.0/20"
}

variable "hcp_vault_cluster_id" {
  description = "HCP Vault cluster ID."
  type        = string
  default     = "ezra-vault"
}

variable "hcp_vault_tier" {
  description = "HCP Vault tier. For free tier use dev."
  type        = string
  default     = "dev"

  validation {
    condition = contains([
      "dev",
      "standard_small",
      "standard_medium",
      "standard_large",
      "plus_small",
      "plus_medium",
      "plus_large"
    ], var.hcp_vault_tier)
    error_message = "hcp_vault_tier must be a valid HCP Vault tier."
  }
}

variable "hcp_vault_public_endpoint" {
  description = "Enable public endpoint for the HCP Vault cluster."
  type        = bool
  default     = true
}

variable "create_hcp_vault_admin_token" {
  description = "Generate and manage an HCP Vault admin token for bootstrap operations."
  type        = bool
  default     = true
}

variable "create_tfe_organization" {
  description = "Create the HCP Terraform organization. Set false to use an existing org."
  type        = bool
  default     = false
}

variable "tfe_hostname" {
  description = "HCP Terraform/TFE hostname."
  type        = string
  default     = "app.terraform.io"
}

variable "tfe_organization_name" {
  description = "HCP Terraform organization name for backend state workspaces."
  type        = string
  default     = "karl-vanderslice-org"
}

variable "tfe_organization_email" {
  description = "Admin email for organization creation (required if create_tfe_organization is true)."
  type        = string
  default     = null

  validation {
    condition     = !var.create_tfe_organization || var.tfe_organization_email != null
    error_message = "Set tfe_organization_email when create_tfe_organization is true."
  }
}

variable "tfe_project_name" {
  description = "Project name for backend-state-only workspaces."
  type        = string
  default     = "terraform-backend-state"
}

variable "tfe_project_description" {
  description = "Project description for backend-state-only workspaces."
  type        = string
  default     = "Backend state workspaces for terraform-* repositories"
}

variable "tfe_project_tags" {
  description = "Tags to apply to the backend-state project."
  type        = map(string)
  default = {
    managed_by = "terraform"
    purpose    = "backend-state"
    owner      = "ezra"
  }
}

variable "tfe_workspace_tag_names" {
  description = "Tag names applied to each backend-state workspace."
  type        = list(string)
  default     = ["backend-state", "terraform", "ezra"]
}

variable "terraform_backend_workspace_names" {
  description = "Workspace names to create for terraform-* repositories using backend state only."
  type        = list(string)
  default = [
    "terraform-cloudflare-api-token-bootstrap",
    "terraform-cloudflare-docs-sites",
    "terraform-hcp-bootstrap"
  ]
}
