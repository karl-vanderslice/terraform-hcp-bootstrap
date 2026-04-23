# AGENTS

## Purpose

This repository bootstraps HCP and HCP Terraform resources for backend and
platform setup.

## Documentation Standards

- Keep `README.md` as the GitHub entrypoint and `docs/index.md` as the docs
  landing page.
- Do not add duplicate overview pages such as `docs/README.md`.
- Keep Terraform variable, output, and module descriptions complete enough for
  `terraform-docs`; generated Markdown is the canonical reference surface.
- Prefer `just` targets in docs when they exist instead of duplicating raw
  Terraform and shell commands.
- Separate backend usage, authentication, and recovery workflows from the
  generated Terraform reference tables.
