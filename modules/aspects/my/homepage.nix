let
  port = 8082;
  port' = toString port;
in
{
  den.quirks.homepage-entry.description = "Homepage dashboard service entries";

  my.homepage = {
    virtual-host = {
      name = "homepage";
      url = "harmony.silverlight-nex.us";
      inherit port;
    };

    secrets = { secrets, ... }: {
      "homepage-dashboard.env".generator = {
        dependencies = { inherit (secrets) prowlarr-api-key radarr-api-key sonarr-api-key; };
        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'HOMEPAGE_VAR_PROWLARR_API_KEY="%s"\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.prowlarr-api-key.file}
            )"
            printf 'HOMEPAGE_VAR_RADARR_API_KEY="%s"\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.radarr-api-key.file}
            )"
            printf 'HOMEPAGE_VAR_SONARR_API_KEY="%s"\n' "$(
              ${decrypt} ${lib.escapeShellArg deps.sonarr-api-key.file}
            )"
          '';
      };
    };

    nixos =
      {
        config,
        virtual-host,
        homepage-entry,
        lib,
        ...
      }:
      let
        hosts = lib.listToAttrs (map (host: lib.nameValuePair host.name host) virtual-host);
        urlFor = name: "https://${hosts.${name}.url}";

        groups = lib.unique (map (entry: entry.group) homepage-entry);
        entryToService = entry: {
          ${entry.label} = {
            inherit (entry) href description;
          }
          // lib.optionalAttrs (entry ? widget) { inherit (entry) widget; };
        };
      in
      {
        services.homepage-dashboard = {
          enable = true;
          environmentFiles = [ config.age.secrets."homepage-dashboard.env".path ];
          allowedHosts = "localhost:${port'},127.0.0.1:${port'},${hosts.homepage.url}";
          widgets = [
            {
              glances = {
                url = "http://127.0.0.1:${toString config.services.glances.port}";
                version = 4;
                cputemp = true;
                uptime = true;
                disk = [
                  "/"
                  "/metalminds"
                ];
                expanded = true;
              };
            }
          ];
          services = map (group: {
            ${group} = map entryToService (lib.filter (entry: entry.group == group) homepage-entry);
          }) groups;
          bookmarks = [
            {
              "Servers" = [
                {
                  "Harmony" = [
                    {
                      abbr = "HA";
                      href = urlFor "homepage";
                    }
                  ];
                }
              ];
            }
          ];
        };
      };
  };
}
