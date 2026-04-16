locals {
  hcp_project_id = var.create_hcp_project ? hcp_project.ezra[0].resource_id : var.hcp_project_id

  tfe_organization_name = var.create_tfe_organization ? tfe_organization.backend_state[0].name : var.tfe_organization_name

  terraform_backend_workspace_names = toset(var.terraform_backend_workspace_names)
}

resource "hcp_project" "ezra" {
  count = var.create_hcp_project ? 1 : 0

  name        = var.hcp_project_name
  description = var.hcp_project_description
}

resource "hcp_hvn" "ezra" {
  count = var.enable_hcp_vault ? 1 : 0

  hvn_id         = var.hcp_hvn_id
  cloud_provider = var.hcp_hvn_cloud_provider
  region         = var.hcp_hvn_region
  cidr_block     = var.hcp_hvn_cidr_block
  project_id     = local.hcp_project_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcp_vault_cluster" "ezra" {
  count = var.enable_hcp_vault ? 1 : 0

  cluster_id      = var.hcp_vault_cluster_id
  hvn_id          = hcp_hvn.ezra[0].hvn_id
  project_id      = local.hcp_project_id
  tier            = var.hcp_vault_tier
  public_endpoint = var.hcp_vault_public_endpoint

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcp_vault_cluster_admin_token" "ezra" {
  count = var.enable_hcp_vault && var.create_hcp_vault_admin_token ? 1 : 0

  cluster_id = hcp_vault_cluster.ezra[0].cluster_id
  project_id = local.hcp_project_id
}

resource "tfe_organization" "backend_state" {
  count = var.create_tfe_organization ? 1 : 0

  name  = var.tfe_organization_name
  email = var.tfe_organization_email
}

resource "tfe_project" "backend_state" {
  organization = local.tfe_organization_name
  name         = var.tfe_project_name
  description  = var.tfe_project_description
  tags         = var.tfe_project_tags
}

resource "tfe_workspace" "terraform_projects" {
  for_each = local.terraform_backend_workspace_names

  name           = each.key
  organization   = local.tfe_organization_name
  project_id     = tfe_project.backend_state.id
  queue_all_runs = false
  tag_names      = var.tfe_workspace_tag_names
}

resource "tfe_workspace_settings" "terraform_projects" {
  for_each = tfe_workspace.terraform_projects

  workspace_id         = each.value.id
  execution_mode       = "local"
  global_remote_state  = false
  project_remote_state = false
}
