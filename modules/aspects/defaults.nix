{
  config,
  den,
  my,
  ...
}:
{
  # These are functions that produce configs
  den.default.includes = [
    # ${user}.provides.${host} and ${host}.provides.${user}
    my.routes

    # Enable home-manager on all hosts.
    { homeManager.programs.home-manager.enable = true; }

    # Automatically create the user on host.
    den._.define-user

    # Disable booting when running on CI on all NixOS hosts.
    (if config ? _module.args.CI then my.ci-no-boot else { })

    # NOTE: be cautious when adding fully parametric functions to defaults. defaults are included on EVERY
    # host/user/home, and IF you are not careful you could be duplicating config values. For example:
    #
    # This will append 42 into foo option for the {host} and for EVERY {host,user}
    #
    # ({ host, ... }: { nixos.foo = [ 42 ]; }) # DO-NOT-DO-THIS.
    #
    # Instead try to be explicit if a function is intended for ONLY { host }.
    (den.lib.take.exactly ({ host }: { nixos.networking.hostName = host.hostName; }))
  ];
}
