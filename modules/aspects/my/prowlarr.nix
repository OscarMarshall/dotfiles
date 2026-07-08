{
  my.prowlarr =
    let
      url = "prowlarr.harmony.silverlight-nex.us";
      port = 9696;
    in
    {
      virtual-host = {
        name = "prowlarr";
        inherit url port;
      };

      homepage-entry = {
        group = "Arr Stack";
        label = "Prowlarr";
        description = "Indexer manager/proxy";
        href = "https://${url}";
        widget = {
          type = "prowlarr";
          url = "https://${url}";
          key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
        };
      };

      secrets = { secrets, ... }: {
        prowlarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
        };
        "prowlarr.env".generator = {
          dependencies = { inherit (secrets) prowlarr-api-key; };
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'PROWLARR__AUTH__APIKEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file})"
            '';
        };
      };

      nixos = { config, ... }: {
        services = {
          prowlarr = {
            enable = true;
            settings.server = { inherit port; };
            environmentFiles = [ config.age.secrets."prowlarr.env".path ];
          };
          flaresolverr.enable = true;
        };
      };
    };
}
