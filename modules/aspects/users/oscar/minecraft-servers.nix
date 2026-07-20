{ my, ... }:
let
  worlds = {
    chicken-house = {
      port = 25566;

      server = pkgs: {
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
        enable = true;
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
        enable = true;
        package = pkgs.fabricServers.fabric-1_21_11;
        serverProperties.white-list = false;
      };
    };
  };
in
{
  den.aspects.oscar.provides.minecraft-servers = {
    includes = [
      (my.minecraft-servers {
        inherit worlds;
        administrators = [ "oscar" ];
      })
    ];
  };
}
