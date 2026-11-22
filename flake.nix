{
  description = "Project Alias - rename your assistant and make sure it never listens";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      devshell,
      git-hooks,
      nix-github-actions,
    }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      pkgsAarch64 = import nixpkgs { system = "aarch64-linux"; };

      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.difference (lib.fileset.unions [
          ./src/app.py
          ./src/modules
          ./data
          ./imgs
          ./nix
          ./.github
          ./flake.nix
          ./flake.lock
          ./LICENSE.GPL
        ]) ./src/modules/__pycache__;
      };

      lintSrc = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
          ./src/app.py
          ./src/modules
          ./nix
          ./.github
          ./flake.nix
        ];
      };

      pre-commit = git-hooks.lib.${system}.run {
        src = lintSrc;
        hooks = {
          ruff.enable = true;
          ruff-format.enable = true;
          nixfmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;
          gitlint.enable = true;
          trim-trailing-whitespace.enable = true;
          end-of-file-fixer.enable = true;
          check-yaml.enable = true;
          check-merge-conflicts.enable = true;
        };
      };
    in
    {
      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = lib.getAttrs [ system ] self.checks;
      };

      # The pre-commit runner is intentionally not exposed as a check: it
      # executes every hook at build time, which duplicates the individual
      # checks below. Its value is the devshell startup hook only.
      checks.${system} = {
        ruff-check = pkgs.runCommand "check-ruff" { buildInputs = [ pkgs.ruff ]; } ''
          ${pkgs.ruff}/bin/ruff check --no-cache ${lintSrc}
          touch $out
        '';
        ruff-format = pkgs.runCommand "check-ruff-format" { buildInputs = [ pkgs.ruff ]; } ''
          ${pkgs.ruff}/bin/ruff format --check --no-cache ${lintSrc}
          touch $out
        '';
        nixfmt = pkgs.runCommand "check-nixfmt" { buildInputs = [ pkgs.nixfmt-rfc-style ]; } ''
          find ${lintSrc} -name '*.nix' -print0 | xargs -0 --no-run-if-empty ${pkgs.nixfmt-rfc-style}/bin/nixfmt --check
          touch $out
        '';
        statix = pkgs.runCommand "check-statix" { buildInputs = [ pkgs.statix ]; } ''
          ${pkgs.statix}/bin/statix check ${lintSrc}
          touch $out
        '';
        deadnix = pkgs.runCommand "check-deadnix" { buildInputs = [ pkgs.deadnix ]; } ''
          ${pkgs.deadnix}/bin/deadnix --fail ${lintSrc}
          touch $out
        '';
      };

      devShells.${system}.default = devshell.legacyPackages.${system}.mkShell {
        packages = with pkgs; [
          python3
          ruff
          nixfmt-rfc-style
          statix
          deadnix
          gitlint
          pre-commit.config.package
        ];
        devshell.startup.pre-commit.text = pre-commit.shellHook;
      };

      # Kept out of checks so the CI matrix stays lint-only; run with
      # nix build .#tests.x86_64-linux.basic (requires a kvm-capable host).
      tests.${system}.basic = import ./tests/basic.nix {
        inherit self pkgs;
      };

      packages.aarch64-linux = {
        project-alias = import ./nix/package.nix {
          inherit lib src;
          python3Packages = pkgsAarch64.python313Packages;
        };
        seeed-voicecard = import ./nix/seeed-voicecard.nix {
          inherit lib;
          pkgs = pkgsAarch64;
        };
        default = self.packages.aarch64-linux.project-alias;
      };

      nixosModules.project-alias = import ./nix/nixos-module.nix self;
    };
}
