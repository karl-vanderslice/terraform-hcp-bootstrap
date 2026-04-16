terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.111"
    }

    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.76"
    }
  }
}

provider "hcp" {}

provider "tfe" {
  hostname = var.tfe_hostname
}
