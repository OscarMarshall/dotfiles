{
  flake.modules.nixos.apcupsd = _: {
    services.apcupsd.enable = true;
  };
}
