{
  config,
  inputs,
  lib,
  ...
}: {
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [inputs.nix-minecraft.overlay];
    hostPlatform = lib.mkIf (config.networking.hostName == "omarshal-m-2fd2") "aarch64-darwin";
  };
}
