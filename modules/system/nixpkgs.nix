{inputs, ...}: {
  flake.modules.nixos.nixpkgs = {
    nixpkgs = {
      config.allowUnfree = true;
      overlays = [inputs.nix-minecraft.overlay];
    };
  };
}
