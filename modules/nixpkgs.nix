{
  inputs,
  lib,
  ...
}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "minecraft-server"
          "neoforge"
          "plexmediaserver"
        ];
    };
    overlays = [inputs.nix-minecraft.overlay];
  };
}
