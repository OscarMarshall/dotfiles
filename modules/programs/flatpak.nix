{
  flake.modules.nixos.flatpak = _: {
    services.flatpak.enable = true;
  };
}
