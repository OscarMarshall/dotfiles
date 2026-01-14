{inputs, ...}: {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: {
    # Run the hooks with `nix fmt`.
    formatter = let
      inherit (config.checks.pre-commit-check) config;
      inherit (config) package configFile;
      script = ''
        ${pkgs.lib.getExe package} run --all-files --config ${configFile}
      '';
    in
      pkgs.writeShellScriptBin "pre-commit-run" script;

    # Run the hooks in a sandbox with `nix flake check`.
    # Read-only filesystem and no internet access.
    checks.pre-commit-check = inputs.git-hooks.lib.${system}.run {
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

    # Enter a development shell with `nix develop`.
    # The hooks will be installed automatically.
    # Or run pre-commit manually with `nix develop -c pre-commit run --all-files`
    devShells.default = let
      inherit (config.checks.pre-commit-check) shellHook enabledPackages;
    in
      pkgs.mkShell {
        inherit shellHook;
        buildInputs = enabledPackages;
      };
  };
}
