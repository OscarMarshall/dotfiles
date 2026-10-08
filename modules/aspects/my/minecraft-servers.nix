{
  lib,
  den,
  inputs,
  ...
}:
{
  flake-file.inputs.nix-minecraft = {
    url = "github:Infinidoge/nix-minecraft";

    inputs = {
      flake-compat.follows = "flake-compat";
      nixpkgs.follows = "nixpkgs";
      systems.follows = "systems";
    };
  };

  # `worlds` is an attrset keyed by world name:
  #   <name> = {
  #     port = <int>;        # game port - drives both serverProperties.server-port and DNS below
  #     server = pkgs: {...}; # the rest of services.minecraft-servers.servers.<name> (package,
  #                           # remaining serverProperties, symlinks, etc.) - a function since
  #                           # `pkgs` isn't available yet at the aspect's own call site (see
  #                           # harmony.nix), only once `nixos` is resolved.
  #     mods = {            # optional: Fabric mods by Modrinth slug, resolved into `modsLock`
  #       <slug> = { };     #   newest release build
  #       <slug>.channel = "beta"; # also accept beta (or "alpha") builds
  #     };
  #     gameVersion = "1.21.8"; # optional, with `mods`: pin Minecraft instead of tracking the
  #                             # newest release every mod supports
  #   };
  # `port` is kept separate (rather than read out of `server`) so DNS generation below never needs
  # a real `pkgs` at all. `modsLock` is the imported lock file `nix run .#update-minecraft-mods`
  # writes (see the host's own minecraft-servers.nix, which defines that package).
  my.minecraft-servers =
    {
      worlds,
      administrators ? [ ],
      modsLock ? { },
    }:
    { host, ... }:
    let
      inherit (host) domain;
    in
    {
      includes = [
        (den._.unfree [
          "minecraft-server"
          "neoforge"
        ])
      ];

      dataset = {
        # ZFS COW means restic won't catch a torn write mid-save, but an in-progress autosave
        # could still land a half-written region file in a backup - so quiesce every ENABLED
        # world (`create-think-bigger` is currently `enable = false;`, crash-looping, see its own
        # comment - `world.server pkgs` is re-checked here rather than assumed, since nothing
        # else tracks which worlds are actually running) around the backup.
        #
        # tmux (nix-minecraft's DEFAULT management system - the one it uses for its own stop
        # command - not rcon: `vanilla` doesn't even have rcon enabled, only `chicken-house`
        # does, but every enabled world gets a console tmux socket at
        # `services.minecraft-servers.runDir` (default, unoverridden here: `/run/minecraft`)
        # regardless). `send-keys` just injects keystrokes with no synchronous ack, so `sleep 5`
        # after `save-all` approximates "done" for worlds this size - the same fixed-wait
        # mcrcon's own `-w` flag exists for. `|| true` on every call: a world that happens to be
        # stopped when the daily timer fires isn't being written to anyway, so failing to
        # quiesce it is harmless and must not abort backing up the OTHER worlds sharing this
        # dataset.
        backup =
          pkgs:
          let
            enabledWorldNames = builtins.attrNames (lib.filterAttrs (_: world: (world.server pkgs).enable or true) worlds);
            sendCommand =
              command:
              lib.concatMapStrings (world: ''
                ${tmux} -S ${lib.escapeShellArg "/run/minecraft/${world}.sock"} send-keys ${lib.escapeShellArg command} Enter || true
              '') enabledWorldNames;
            tmux = "${pkgs.tmux}/bin/tmux";
          in
          {
            backupCleanupCommand = sendCommand "save-on";
            backupPrepareCommand = sendCommand "save-off" + sendCommand "save-all" + "sleep 5\n";
          };

        guestAccess = true;
        name = "minecraft-worlds";
        pool = "metalminds";
        samba = true;
        # One nix-minecraft-generated `minecraft-server-<world>.service` per world - all share this
        # one dataset (`dataDir` below), so all need to wait on it.
        units = map (world: "minecraft-server-${world}") (lib.attrNames worlds);
      };

      nixos =
        { config, pkgs, ... }:
        let
          # A world with `mods` gets its Fabric server AND its mods from `modsLock` (written by
          # `nix run .#update-minecraft-mods`, see minecraft-servers/update-mods.py), never from
          # `fabricServers.fabric` (latest) - #896's nix-minecraft bump once moved `vanilla` onto
          # Minecraft 26.3 while every mod was still a 26.2 build, and Fabric Loader refused to start
          # (a silent crash loop: nix-minecraft's tmux wrapper swallows the JVM's output). With the
          # game version pinned in the same lock as the mods, only the updater moves it, and only
          # to a version every mod already supports.
          lockedServer =
            name: world: server:
            let
              escapedVersion = lib.replaceStrings [ "." " " ] [ "_" "_" ] locked.gameVersion;
              locked =
                modsLock.${name}
                  or (throw "my.minecraft-servers: world `${name}` has `mods` but no lock entry - run `nix run .#update-minecraft-mods`");
            in
            assert lib.assertMsg
              (
                # Compares each mod's channel too (not just the set of names), so switching a mod
                # to e.g. `channel = "beta"` also demands a re-resolve.
                lib.mapAttrs (_: mod: mod.channel or "release") world.mods == lib.mapAttrs (_: mod: mod.channel) locked.mods
                && (world.gameVersion or locked.gameVersion) == locked.gameVersion
              )
              "my.minecraft-servers: `${name}`'s lock is out of date with its `mods` (names or channels)/`gameVersion` - run `nix run .#update-minecraft-mods`";
            {
              # nix-minecraft's `mkTextileServer` doesn't inherit the JDK from the vanilla server
              # it wraps (`vanillaServers.<version>.java` - nix-minecraft's own pick, the newest
              # JDK it packages for anything past Java 8) - it uses nixpkgs' ambient
              # `jre_headless`, and a server newer than that JDK exits instantly with
              # UnsupportedClassVersionError (happened 2026-08-24: 26.2 needed Java 25, ambient
              # was 21). Always run what nix-minecraft runs its own vanilla server on instead.
              package = pkgs.fabricServers."fabric-${escapedVersion}".override {
                jre_headless = pkgs.vanillaServers."vanilla-${escapedVersion}".java;
              };

              symlinks = (server.symlinks or { }) // {
                mods = pkgs.linkFarmFromDrvs "mods" (
                  lib.mapAttrsToList (_: mod: pkgs.fetchurl { inherit (mod) sha512 url; }) locked.mods
                );
              };
            };
        in
        {
          imports = [ (inputs.nix-minecraft.nixosModules.minecraft-servers or { }) ];
          nixpkgs.overlays = [ (inputs.nix-minecraft.overlay or { }) ];

          services.minecraft-servers = {
            enable = true;
            dataDir = "/metalminds/minecraft-worlds";
            environmentFile = config.age.secrets."minecraft-servers.env".path;
            eula = true;
            openFirewall = true;

            servers = lib.mapAttrs (
              name: world:
              let
                server = world.server pkgs;
              in
              server
              // lib.optionalAttrs (world ? mods) (lockedServer name world server)
              // {
                serverProperties = (server.serverProperties or { }) // {
                  server-port = world.port;
                };
              }
            ) worlds;
          };

          users.users = lib.genAttrs administrators (user: {
            extraGroups = [ "minecraft" ];
          });
        };

      # One inbound rule per world, on its own game port (see modules/aspects/my/meraki.nix).
      port-forward = lib.mapAttrsToList (name: world: {
        inherit (world) port;
        name = "minecraft-${name}";
      }) worlds;

      secrets = { secrets, ... }: {
        "minecraft-servers.env".generator = {
          dependencies = { inherit (secrets) oscar-password; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'RCON_PASSWORD="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.oscar-password.file})"
            '';
        };
      };

      # A world at `<name>.minecraft.${domain}` (an A/CNAME record, same type/content as every
      # other DNS record this host produces - see modules/aspects/my/dns.nix) plus a
      # `_minecraft._tcp` SRV record pointing at that same hostname on its actual game port, so
      # players can connect to `<name>.minecraft.${domain}` without specifying a port. No new
      # quirk needed - unlike the HTTP services in dns.nix, nothing else (nginx, Homepage) needs to
      # know about Minecraft worlds, so this aspect just contributes directly to the shared
      # `terranix` class alongside dns.nix's own contribution (same host, same
      # `host.cloudflare-zone-id` - see modules/den.nix). A plain attrset, not a function - see
      # modules/terranix.nix for why that matters.
      terranix = lib.optionalAttrs (host ? dns-record) {
        resource.cloudflare_dns_record = lib.concatMapAttrs (name: world: {
          "minecraft-${name}" = {
            inherit (host.dns-record) content type;
            name = "${name}.minecraft.${domain}";
            proxied = false;
            ttl = 1800;
            zone_id = host.cloudflare-zone-id;
          };

          "minecraft-${name}-srv" = {
            data = {
              inherit (world) port;
              name = "${name}.minecraft.${domain}";
              priority = 0;
              proto = "_tcp";
              target = "${name}.minecraft.${domain}";
              weight = 0;
            };

            name = "_minecraft._tcp.${name}.minecraft.${domain}";
            priority = 0;
            ttl = 1800;
            type = "SRV";
            zone_id = host.cloudflare-zone-id;
          };
        }) worlds;
      };
    };
}
