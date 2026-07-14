{
  my.prowlarr =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 9696;
    in
    {
      virtual-host = {
        name = "prowlarr";
        host = host.name;
        inherit port global;
        homepage = {
          group = "Arr Stack";
          label = "Prowlarr";
          description = "Indexer manager/proxy";
          widget = {
            type = "prowlarr";
            apiKeySecret = "prowlarr-api-key";
          };
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
