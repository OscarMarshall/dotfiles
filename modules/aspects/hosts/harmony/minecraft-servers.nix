{
  lib,
  inputs,
  my,
  ...
}:
let
  # Written by `nix run .#update-minecraft-mods` (below) - never edit by hand. Every world with
  # `mods` takes both its Minecraft version and its mod jars from here (see
  # modules/aspects/my/minecraft-servers.nix).
  lockFile = ./minecraft-mods.lock.json;
  whitelist = {
    AshamedMunchkin = "330378c0-3b95-44ad-a16f-63c51c87997a";
    birdonapalmtree = "81c5ebad-8cd8-46b1-8267-93fe7ace11dc";
    rawriana2200 = "9b34899e-073a-49e5-8123-f60a8ae4965d";
    sunsetfunset = "ba9c558c-3546-4cdb-876d-e4a7853b76c9";
    tishara_T = "3831d61e-3a13-499c-badb-ec2babf30374";
  };
  worlds = {
    chicken-house = {
      # Pinned: a Minecraft upgrade rewrites the world irreversibly, and this one has no reason
      # to chase new releases - the updater still keeps its mods current within 1.21.8.
      gameVersion = "1.21.8";

      mods = {
        architectury-api = { };
        autowhitelist = { };
        cloth-config = { };
        fabric-api = { };
        fabric-language-kotlin = { };
        ferrite-core = { };
        jade = { };
        lithium = { };
        rei = { };
      };

      port = 25566;

      server = pkgs: {
        inherit whitelist;
        enable = true;

        serverProperties = {
          enable-rcon = true;
          "rcon.password" = "@RCON_PASSWORD@";
          "rcon.port" = 25576;
          white-list = true;
        };
      };
    };

    create-think-bigger = {
      port = 25567;

      server = pkgs: {
        inherit whitelist;
        # Crash-loops on boot: moonlight-1.21-2.18.13-neoforge.jar's moonlight-common.mixins.json
        # has no "refmap" field, so Mixin can't resolve the embedded moonlight-common-refmap.json
        # and PoiMixin's (required) injection fails, aborting the JVM before the world loads. Needs
        # a mod-jar fix in mods/ (unmanaged by Nix) - disabled until then.
        enable = false;
        package = pkgs.neoforgeServers.neoforge-1_21_1;

        serverProperties = {
          enable-rcon = true;
          "rcon.password" = "@RCON_PASSWORD@";
          "rcon.port" = 25577;
          white-list = true;
        };
      };
    };

    # Unpinned: follows the newest Minecraft release that every mod below has a build for.
    vanilla = {
      mods = {
        appleskin = { };
        fabric-api = { };
        ferrite-core = { };
        jade = { };
        # JEI only publishes betas for new Minecraft versions for weeks after release.
        jei.channel = "beta";
        lithium = { };
      };

      port = 25565;

      server = pkgs: {
        inherit whitelist;
        enable = true;
        enableReload = true;
        serverProperties.white-list = true;
      };
    };
  };
in
{
  den.aspects.harmony.provides.minecraft-servers.includes = [
    (my.minecraft-servers {
      inherit worlds;
      administrators = [ "oscar" ];
      modsLock = lib.importJSON lockFile;
    })
  ];

  # `nix run .#update-minecraft-mods` - re-resolves every world's `mods` against Modrinth and
  # rewrites `lockFile` in place (run from anywhere inside this repo's checkout). Also run daily by
  # .github/workflows/update-minecraft-mods.yml, which opens a PR with the result.
  perSystem =
    { pkgs, ... }:
    let
      spec = pkgs.writeText "minecraft-mods-spec.json" (
        builtins.toJSON {
          # Every game version nix-minecraft can build a Fabric server for - the updater never
          # picks one outside this set, so a lock it writes always evaluates.
          availableGameVersions = lib.attrNames (lib.importJSON "${inputs.nix-minecraft}/pkgs/fabric-servers/game_locks.json");

          worlds = lib.mapAttrs (_: world: {
            gameVersion = world.gameVersion or null;
            loader = "fabric";
            mods = lib.mapAttrs (_: mod: { channel = mod.channel or "release"; }) world.mods;
          }) (lib.filterAttrs (_: world: world ? mods) worlds);
        }
      );
    in
    {
      packages.update-minecraft-mods = pkgs.writeShellApplication {
        name = "update-minecraft-mods";

        runtimeInputs = [
          pkgs.git
          pkgs.python3
        ];

        text = ''
          cd "$(git rev-parse --show-toplevel)"
          python3 ${../../my/minecraft-servers/update-mods.py} ${spec} modules/aspects/hosts/harmony/minecraft-mods.lock.json
        '';
      };
    };
}
