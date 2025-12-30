{
  config,
  pkgs,
  ...
}: {
  services.minecraft-servers = {
    enable = true;
    openFirewall = true;
    eula = true;
    dataDir = "/metalminds/minecraft-worlds";
    environmentFile = config.age.secrets."minecraft-servers.env".path;
    servers = {
      chicken-house = {
        enable = true;
        package = pkgs.fabricServers.fabric-1_21_8;
        serverProperties = {
          server-port = 25566;
          white-list = true;
          enable-rcon = true;
          "rcon.port" = 25576;
          "rcon.password" = "@RCON_PASSWORD@";
        };
        symlinks = {
          mods = pkgs.linkFarmFromDrvs "mods" (
            builtins.attrValues {
              ArchitecturyAPI = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/XcJm5LH4/architectury-17.0.8-fabric.jar";
                sha256 = "sha256-tdBR+O/+j5R2+TdeEeSN+vuCF5FDW4/jaIaZADl/BdU=";
              };
              AutoWhitelist = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/BMaqFQAd/versions/PIJ4HDyR/autowhitelist-1.2.4%2B1.21.6.jar";
                sha256 = "sha256-cYTNxZEGfyUVAkSeFk8Ci3FbcpJOmgeSXqE++NB9BYM=";
              };
              # Carpet = pkgs.fetchurl {
              #   url = "https://cdn.modrinth.com/data/TQTTVgYE/versions/xksYKkvF/fabric-carpet-1.20.2-1.4.121%2Bv231011.jar";
              #   sha256 = "sha256-qGprKkfOVzmNVH/nzOCRC569Q3w7GdxyD6PAoQtji+w=";
              # };
              ClothConfig = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/9s6osm5g/versions/cz0b1j8R/cloth-config-19.0.147-fabric.jar";
                sha256 = "sha256-2KbcqdDa0f5EYio8agNIZBk045Q8jUJaJvESvObev6I=";
              };
              FabricAPI = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/jjBL6OsN/fabric-api-0.132.0%2B1.21.8.jar";
                sha256 = "sha256-t2MBX17VRswnCzHspYKty6JkzWKJ5FFF2fU0jGD9olk=";
              };
              FabricLanguageKotlin = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/mccDBWqV/fabric-language-kotlin-1.13.4%2Bkotlin.2.2.0.jar";
                sha256 = "sha256-KjxW/B3W6SKpvuNaTAukvA2Wd2Py6VL/SbdOw8ZB9Qs=";
              };
              FerriteCore = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/uXXizFIs/versions/CtMpt7Jr/ferritecore-8.0.0-fabric.jar";
                sha256 = "sha256-K5C/AMKlgIw8U5cSpVaRGR+HFtW/pu76ujXpxMWijuo=";
              };
              Jade = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/o3aatc5Q/Jade-1.21.8-Fabric-19.3.2.jar";
                sha256 = "sha256-RWjPJiGJqedV9kYagfaypBNCcYF8edVOJB776Y02J9A=";
              };
              Lithium = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/pDfTqezk/lithium-fabric-0.18.0%2Bmc1.21.8.jar";
                sha256 = "sha256-kBPy+N/t6v20OBddTHZvW0E95WLc0RlaUAIwxVFxeH4=";
              };
              RoughlyEnoughItems = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/nfn13YXA/versions/hoEFy7aF/RoughlyEnoughItems-20.0.811-fabric.jar";
                sha256 = "sha256-e2t1DkKcRCCF+gdFsDwnOyQiTxzngF2DnrUqmfKwJTo=";
              };
            }
          );
        };
      };
      create-think-bigger = {
        enable = true;
        package = pkgs.neoforgeServers.neoforge-1_21_1;
        serverProperties = {
          server-port = 25567;
          white-list = true;
          enable-rcon = true;
          "rcon.port" = 25577;
          "rcon.password" = "@RCON_PASSWORD@";
        };
      };
    };
  };
}
