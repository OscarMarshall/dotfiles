{ lib, my, ... }:
let
  whitelist = {
    AshamedMunchkin = "330378c0-3b95-44ad-a16f-63c51c87997a";
    birdonapalmtree = "81c5ebad-8cd8-46b1-8267-93fe7ace11dc";
    rawriana2200 = "9b34899e-073a-49e5-8123-f60a8ae4965d";
    sunsetfunset = "ba9c558c-3546-4cdb-876d-e4a7853b76c9";
    tishara_T = "3831d61e-3a13-499c-badb-ec2babf30374";
  };

  worlds = {
    chicken-house = {
      port = 25566;

      server = pkgs: {
        inherit whitelist;
        enable = true;
        package = pkgs.fabricServers.fabric-1_21_8;

        serverProperties = {
          enable-rcon = true;
          "rcon.password" = "@RCON_PASSWORD@";
          "rcon.port" = 25576;
          white-list = true;
        };

        symlinks.mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {
            ArchitecturyAPI = pkgs.fetchurl {
              sha256 = "sha256-tdBR+O/+j5R2+TdeEeSN+vuCF5FDW4/jaIaZADl/BdU=";
              url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/XcJm5LH4/architectury-17.0.8-fabric.jar";
            };

            AutoWhitelist = pkgs.fetchurl {
              sha256 = "sha256-cYTNxZEGfyUVAkSeFk8Ci3FbcpJOmgeSXqE++NB9BYM=";
              url = "https://cdn.modrinth.com/data/BMaqFQAd/versions/PIJ4HDyR/autowhitelist-1.2.4%2B1.21.6.jar";
            };

            # Carpet = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/TQTTVgYE/versions/xksYKkvF/fabric-carpet-1.20.2-1.4.121%2Bv231011.jar";
            #   sha256 = "sha256-qGprKkfOVzmNVH/nzOCRC569Q3w7GdxyD6PAoQtji+w=";
            # };
            ClothConfig = pkgs.fetchurl {
              sha256 = "sha256-2KbcqdDa0f5EYio8agNIZBk045Q8jUJaJvESvObev6I=";
              url = "https://cdn.modrinth.com/data/9s6osm5g/versions/cz0b1j8R/cloth-config-19.0.147-fabric.jar";
            };

            FabricAPI = pkgs.fetchurl {
              sha256 = "sha256-t2MBX17VRswnCzHspYKty6JkzWKJ5FFF2fU0jGD9olk=";
              url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/jjBL6OsN/fabric-api-0.132.0%2B1.21.8.jar";
            };

            FabricLanguageKotlin = pkgs.fetchurl {
              sha256 = "sha256-KjxW/B3W6SKpvuNaTAukvA2Wd2Py6VL/SbdOw8ZB9Qs=";
              url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/mccDBWqV/fabric-language-kotlin-1.13.4%2Bkotlin.2.2.0.jar";
            };

            FerriteCore = pkgs.fetchurl {
              sha256 = "sha256-K5C/AMKlgIw8U5cSpVaRGR+HFtW/pu76ujXpxMWijuo=";
              url = "https://cdn.modrinth.com/data/uXXizFIs/versions/CtMpt7Jr/ferritecore-8.0.0-fabric.jar";
            };

            Jade = pkgs.fetchurl {
              sha256 = "sha256-RWjPJiGJqedV9kYagfaypBNCcYF8edVOJB776Y02J9A=";
              url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/o3aatc5Q/Jade-1.21.8-Fabric-19.3.2.jar";
            };

            Lithium = pkgs.fetchurl {
              sha256 = "sha256-kBPy+N/t6v20OBddTHZvW0E95WLc0RlaUAIwxVFxeH4=";
              url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/pDfTqezk/lithium-fabric-0.18.0%2Bmc1.21.8.jar";
            };

            RoughlyEnoughItems = pkgs.fetchurl {
              sha256 = "sha256-e2t1DkKcRCCF+gdFsDwnOyQiTxzngF2DnrUqmfKwJTo=";
              url = "https://cdn.modrinth.com/data/nfn13YXA/versions/hoEFy7aF/RoughlyEnoughItems-20.0.811-fabric.jar";
            };
          }
        );
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

    vanilla = {
      port = 25565;

      server = pkgs: {
        inherit whitelist;
        enable = true;

        # nix-minecraft's fabric-servers `mkTextileServer` wrapper doesn't inherit the JDK
        # from the vanilla-servers package it's built on (`vanillaServers.<version>.java`,
        # picked per-version from versions.json's `javaVersion` field) - it defaults
        # `jre_headless` to plain nixpkgs' ambient `jre_headless` instead. Tracking `fabric`
        # (latest) is fine until Mojang requires a newer JDK than nixpkgs' current default -
        # then the server exits instantly with UnsupportedClassVersionError, no restart will
        # ever fix it, and nix-minecraft's own tmux wrapper swallows the JVM's stderr (see
        # `journalctl -u minecraft-server-vanilla`, which shows nothing past the last normal
        # stop). Happened 2026-08-24: Minecraft 26.2 needs Java 25, nixpkgs' ambient default
        # was still Java 21. Look up the correct JDK from the matching vanillaServers entry
        # (same lookup nix-minecraft's own fabric-servers/default.nix does internally) rather
        # than hardcoding a JDK version, so this keeps working next time Mojang bumps it.
        package =
          let
            escapedVersion = lib.replaceStrings [ "." " " ] [ "_" "_" ] gameVersion;
            gameVersion = pkgs.fabricServers.fabric.passthru.loader.gameVersion;
            requiredJre = pkgs.vanillaServers."vanilla-${escapedVersion}".java;
          in
          # Fires once nixpkgs' ambient `jre_headless` (what `fabricServers.fabric` uses
          # unoverridden - the bug this override works around) catches up to whatever JDK
          # Minecraft ${gameVersion} actually needs: at that point the override above is
          # dead weight, so drop it (and this assertion) back down to `pkgs.fabricServers.fabric`.
          assert
            pkgs.jre_headless.version != requiredJre.version
            || throw "my.harmony.minecraft-servers vanilla: nixpkgs' ambient jre_headless (${pkgs.jre_headless.version}) now matches Minecraft ${gameVersion}'s required JDK (${requiredJre.version}) - the jre_headless override is no longer needed, remove it.";
          pkgs.fabricServers.fabric.override { jre_headless = requiredJre; };

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
    })
  ];
}
