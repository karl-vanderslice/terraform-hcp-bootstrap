{
  description = "Terraform HCP bootstrap dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    git-hooks,
    treefmt-nix,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs = {
          alejandra.enable = true;
          terraform.enable = true;
        };
      };

      preCommitCheck = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          shellcheck = {
            enable = true;
            types_or = ["bash" "shell"];
          };
          markdownlint-cli2 = {
            enable = true;
            name = "markdownlint-cli2";
            entry = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2";
            language = "system";
            files = "\\.md$";
          };
          yamllint = {
            enable = true;
            settings.configuration = ''
              ---
              extends: relaxed
              rules:
                line-length: disable
            '';
          };
          gitleaks = {
            enable = true;
            name = "gitleaks";
            entry = "${pkgs.gitleaks}/bin/gitleaks detect --no-banner --redact --source .";
            language = "system";
            pass_filenames = false;
          };
          checkov = {
            enable = true;
            name = "checkov";
            entry = "${pkgs.checkov}/bin/checkov -d . --config-file .checkov.yaml";
            language = "system";
            pass_filenames = false;
            files = "\\.tf$";
          };
        };
      };
    in {
      formatter = treefmtEval.config.build.wrapper;

      checks = {
        pre-commit = preCommitCheck;
        formatting = treefmtEval.config.build.check self;
      };

      apps.backup-hcp-bootstrap-state = let
        backupWrapper = pkgs.writeShellApplication {
          name = "backup-hcp-bootstrap-state";
          runtimeInputs = [
            pkgs.awscli2
            pkgs.jq
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gawk
            pkgs.findutils
          ];
          text = ''
            exec bash ./scripts/state/backup-local-state-to-ops-bucket.sh
          '';
        };
      in {
        type = "app";
        program = "${backupWrapper}/bin/backup-hcp-bootstrap-state";
      };

      devShells.default = pkgs.mkShell {
        inherit (preCommitCheck) shellHook;
        packages = with pkgs; [
          awscli2
          terraform
          vault
          terraform-docs
          checkov
          gitleaks
          just
          markdownlint-cli2
          shellcheck
          yamllint
          zensical
          jq
          zstd
          age
          sops
          age-plugin-yubikey
        ];
      };
    });
}
