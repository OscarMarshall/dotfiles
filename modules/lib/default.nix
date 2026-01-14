{inputs, ...}: {
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
