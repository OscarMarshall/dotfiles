{
  config,
  den,
  my,
  ...
}:
{
  den.default.homeManager.programs.home-manager.enable = true;

  den.ctx.host.includes = with my; [
    fonts
    nix
    stylix

    # Disable booting when running on CI on all NixOS hosts.
    (if config ? _module.args.CI then my.ci-no-boot else { })

    (
      { host }:
      {
        nixos.networking.hostName = host.hostName;
      }
    )
  ];

  den.ctx.user.includes = [
    # ${user}.provides.${host} and ${host}.provides.${user}
    my.routes

    # Automatically create the user on host.
    den._.define-user
  ];
}
