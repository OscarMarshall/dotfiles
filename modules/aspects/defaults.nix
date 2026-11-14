{
  lib,
  den,
  my,
  self,
  ...
}:
let
  # Core system state every NixOS host needs across reboots on an ephemeral root (my.preservation).
  # `preserve` (modules/aspects/my/preserve.nix) is inert everywhere else. my.preservation
  # suppresses systemd-machine-id-commit, which has nothing to do with this machine-id bind mount.
  corePreserve.preserve = {
    directories = [
      # NixOS uid/gid map - losing this reassigns user/group IDs.
      {
        directory = "/var/lib/nixos";
        inInitrd = true;
      }

      "/var/lib/systemd" # random-seed, timers, backlight, rfkill, coredump
      "/var/log"
    ];

    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
    ];
  };
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

    # Adopt den#694 now: a user aspect's bare `nixos` / `os` content stays with the user, and
    # reaches a host only through the `user` class, `provides.to-hosts` (mutual-provider, below) or
    # a host-level include. Remove after 2027-01-01, when this becomes den's only behaviour.
    migrations.user-host-content.acknowledged = true;

    schema = {
      home.includes = [
        my.nix
        my.starship
        secrets
      ];

      host = {
        includes = [
          corePreserve
          # Delivers users' `provides.to-hosts` (e.g. oscar's trusted-users, my.steam) -
          # opt-in since den#694.
          den.batteries.mutual-provider
          my.fonts
          my.nix
          # pcscd for the YubiKey, so `agenix rekey` / `edit` (age-plugin-yubikey) work on any host.
          my.yubikey
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
