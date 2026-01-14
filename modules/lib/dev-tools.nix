{
  inputs,
  systems,
  ...
}: let
  forEachSystem = inputs.nixpkgs.lib.genAttrs (import systems);
in {
  # Run the hooks with `nix fmt`.
  flake.formatter = forEachSystem (
    system: let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      inherit (inputs.self.checks.${system}.pre-commit-check) config;
      inherit (config) package configFile;
      script = ''
        ${pkgs.lib.getExe package} run --all-files --config ${configFile}
      '';
    in
      pkgs.writeShellScriptBin "pre-commit-run" script
  );

  # Run the hooks in a sandbox with `nix flake check`.
  # Read-only filesystem and no internet access.
  flake.checks = forEachSystem (system: {
    pre-commit-check = inputs.git-hooks.lib.${system}.run {
      src = ./.;
      hooks = {
        alejandra.enable = true;
        flake-checker.enable = true;
        statix.enable = true;
        prettier = {
          enable = true;
          settings.write = true;
        };
      };
    };
  });

  # Enter a development shell with `nix develop`.
  # The hooks will be installed automatically.
  # Or run pre-commit manually with `nix develop -c pre-commit run --all-files`
  flake.devShells = forEachSystem (system: {
    default = let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      inherit (inputs.self.checks.${system}.pre-commit-check) shellHook enabledPackages;
    in
      pkgs.mkShell {
        inherit shellHook;
        buildInputs = enabledPackages;
      };
  });
}
