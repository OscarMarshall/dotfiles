{inputs, lib, ...}: {
  nixpkgs = {
    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "minecraft-server"
      "neoforge"
      "plexmediaserver"
    ];
    overlays = [inputs.nix-minecraft.overlay];
  };
}
