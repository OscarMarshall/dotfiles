{inputs, ...}: {
  flake.modules.nixos.agenix = {
    imports = [inputs.agenix.nixosModules.default];
    environment.systemPackages = [inputs.agenix.packages.x86_64-linux.default];
  };
}
