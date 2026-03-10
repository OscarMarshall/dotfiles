{
  config,
  den,
  my,
  self,
  ...
}:
{
  den = {
    schema.user.classes = [ "homeManager" ];

    ctx = {
      host = {
        includes = with my; [
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

        os.system.configurationRevision = self.rev or self.dirtyRev or null;
      };

      user.includes = with my; [
        # ${user}.provides.${host} and ${host}.provides.${user}
        routes

        # Automatically create the user on host.
        den._.define-user
      ];
    };
  };
}
