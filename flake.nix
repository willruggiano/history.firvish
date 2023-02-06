{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-nix.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.pre-commit-nix.flakeModule
      ];

      systems = ["x86_64-linux" "aarch64-darwin"];
      perSystem = {
        self',
        config,
        pkgs,
        system,
        ...
      }: {
        apps.update-docs.program = pkgs.writeShellApplication {
          name = "update-docs";
          runtimeInputs = with pkgs; [lemmy-help];
          text = ''
            lemmy-help -fact lua/firvish-history.lua > doc/firvish-history.txt
          '';
        };

        devShells.default = pkgs.mkShell {
          name = "history.firvish";
          buildInputs = with pkgs; [lemmy-help luajit];
          shellHook = ''
            ${config.pre-commit.installationScript}
          '';
        };

        formatter = pkgs.alejandra;

        packages = {
          default = pkgs.vimUtils.buildVimPluginFrom2Nix {
            name = "firvish-history-nvim";
            src = ./.;
          };

          firvish-history-nvim = self'.packages.default;
        };

        pre-commit = {
          settings = {
            hooks.alejandra.enable = true;
            hooks.stylua.enable = true;
          };
        };
      };
    };
}
