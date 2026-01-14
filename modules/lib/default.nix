{inputs, ...}: {
  # Set the systems for flake-parts to operate on
  systems = import inputs.systems;

  flake.lib = {
    # Helper to create NixOS configurations following the dendritic pattern
    mkNixos = system: hostName: {
      ${hostName} = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules = [
          {networking.hostName = hostName;}
          inputs.self.modules.nixos.${hostName}
        ];
      };
    };
  };
}
