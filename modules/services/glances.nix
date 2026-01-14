{
  flake.modules.nixos.glances = _: {
    services.glances.enable = true;
  };
}
