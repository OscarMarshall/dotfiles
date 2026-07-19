{
  den,
  inputs,
  lib,
  ...
}:
{
  flake-file.inputs.nix-minecraft = {
    inputs = {
      flake-compat.follows = "flake-compat";
      nixpkgs.follows = "nixpkgs";
      systems.follows = "systems";
    };
    url = "github:Infinidoge/nix-minecraft";
  };

  # `worlds` is an attrset keyed by world name:
  #   <name> = {
  #     port = <int>;        # game port - drives both serverProperties.server-port and DNS below
  #     server = pkgs: {...}; # the rest of services.minecraft-servers.servers.<name> (package,
  #                           # remaining serverProperties, symlinks, etc.) - a function since
  #                           # `pkgs` isn't available yet at the aspect's own call site (see
  #                           # harmony.nix), only once `nixos` is resolved.
  #   };
  # `port` is kept separate (rather than read out of `server`) so DNS generation below never needs
  # a real `pkgs` at all.
  my.minecraft-servers =
    {
      administrators ? [ ],
      worlds,
    }:
    { host, ... }:
    let
      domain = "silverlight-nex.us";
    in
    {
      dataset = {
        guestAccess = true;
        name = "minecraft-worlds";
        pool = "metalminds";
        samba = true;
      };
      includes = [
        (den._.unfree [
          "minecraft-server"
          "neoforge"
        ])
      ];
      nixos = { config, pkgs, ... }: {
        imports = [ (inputs.nix-minecraft.nixosModules.minecraft-servers or { }) ];

        nixpkgs.overlays = [ (inputs.nix-minecraft.overlay or { }) ];

        services.minecraft-servers = {
          dataDir = "/metalminds/minecraft-worlds";
          enable = true;
          environmentFile = config.age.secrets."minecraft-servers.env".path;
          eula = true;
          openFirewall = true;
          servers = lib.mapAttrs (
            _: world:
            let
              server = world.server pkgs;
            in
            server
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
              decrypt,
              deps,
              lib,
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
            inherit (host.dns-record) type content;
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
