{inputs, ...}: {
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [inputs.nix-minecraft.overlay];
  };
}
