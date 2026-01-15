{inputs, ...}: {
  # Set the systems for flake-parts to operate on
  systems = import inputs.systems;

  flake.lib = {
    # Helper to create NixOS configurations following the dendritic pattern
    mkNixos = system: hostName: {
      ${hostName} = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          # Make feature modules available without circular dependency
          inherit (inputs.self) modules;
        };
        modules = [
          {networking.hostName = hostName;}
          ../hosts/${hostName}/configuration.nix
        ];
      };
    };
  };
}
