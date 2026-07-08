{ lib, ... }: {
  my.sonarr =
    let
      url = "sonarr.harmony.silverlight-nex.us";
      port = 8989;
    in
    { administrators }: {
      virtual-host = {
        name = "sonarr";
        inherit url port;
      };

      homepage-entry = {
        group = "Arr Stack";
        label = "Sonarr";
        description = "Show organizer/manager";
        href = "https://${url}";
        widget = {
          type = "sonarr";
          url = "https://${url}";
          key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
          enableQueue = true;
        };
      };

      secrets = { secrets, ... }: {
        sonarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
        };
        "sonarr.env".generator = {
          dependencies = { inherit (secrets) sonarr-api-key; };
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'SONARR__AUTH__APIKEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.sonarr-api-key.file})"
            '';
        };
      };

      nixos = { config, ... }: {
        users.users = {
          sonarr.extraGroups = [ "qbittorrent" ];
        }
        // (lib.genAttrs administrators (user: {
          extraGroups = [ "sonarr" ];
        }));

        services.sonarr = {
          enable = true;
          environmentFiles = [ config.age.secrets."sonarr.env".path ];
        };
      };
    };
}
