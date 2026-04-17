default:
  @just --list

fmt:
  nix develop -c terraform fmt -recursive

format: fmt

init:
  nix develop -c terraform init -upgrade

validate:
  nix develop -c terraform init -backend=false
  nix develop -c terraform validate

plan:
  nix develop -c terraform plan

apply:
  nix develop -c terraform apply

checkov:
  nix develop -c checkov -d . --config-file .checkov.yaml

lint:
  nix flake check --print-build-logs

pre-commit:
  nix build .#checks.x86_64-linux.pre-commit

install-hooks:
  nix develop -c true

terraform-docs:
  nix develop -c terraform-docs markdown table --output-file README.md --output-mode inject .

snapshot-hcp-bootstrap-state:
  nix develop -c bash scripts/state/save-encrypted-state.sh
