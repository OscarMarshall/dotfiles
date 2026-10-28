{
  lib,
  den,
  my,
  self,
  ...
}:
let
  nixosSecrets =
    { aspect-chain, ... }:
    den._.forward {
      adaptArgs = { config, ... }: {
        inherit config;
        inherit (config.age) secrets;
      };

      each = [ "nixos" ];
      fromAspect = _: lib.head aspect-chain;
      fromClass = _: "nixosSecrets";
      intoClass = lib.id;

      intoPath = _: [
        "age"
        "secrets"
      ];
    };
  secrets =
    {
      aspect-chain,
      home ? null,
      ...
    }:
    den._.forward {
      adaptArgs = { config, ... }: {
        inherit config;
        inherit (config.age) secrets;
      };

      each = [
        "nixos"
        "homeManager"
      ];

      fromAspect = _: lib.head aspect-chain;
      fromClass = _: "secrets";
      fromCtx = _: lib.optionalAttrs (home != null) { inherit home; };
      intoClass = lib.id;

      intoPath = _: [
        "age"
        "secrets"
      ];
    };
in
{
  den = {
    default.includes = [
      den.batteries.define-user
      den.batteries.hostname
      den.policies.expose-preserve # lift per-user `preserve` quirk entries to the host - see my/preserve.nix
      my.secrets
    ];

    schema = {
      home.includes = [
        my.nix
        my.starship
        secrets
      ];

      host = {
        includes = [
          my.fonts
          my.nix
          nixosSecrets
          secrets
        ];

        # The one domain every aspect that needs a public hostname (dns.nix, nginx.nix,
        # authentik.nix, etc.) builds off of via `host.domain` - a schema default rather than a
        # per-host attribute since every host shares it today. `mkDefault` so a host could still
        # override it if that ever changes.
        domain = lib.mkDefault "silverlight-nex.us";
        os.system.configurationRevision = self.rev or self.dirtyRev or null;
      };

      user = {
        includes = [
          # Projects `homeManager` config from the host's aspect tree (e.g. my.umbriel/my.noctalia,
          # included by tensoon) onto each of its users.
          den.batteries.host-aspects
          my.starship
        ];

        classes = lib.mkDefault [ "homeManager" ];
      };
    };
  };
}
