{ lib, ... }:
let
  domain = "silverlight-nex.us";
  port = 8082;
  port' = toString port;
  envVarFor = vh: "HOMEPAGE_VAR_${lib.toUpper vh.name}_API_KEY";
in
{
  my.homepage = { host, ... }: {
    virtual-host = {
      name = "homepage";
      host = host.name;
      # Homepage is the host's own root landing page, not a per-service subdomain, so it
      # deliberately doesn't follow the `${name}.${host.name}.${domain}` pattern nginx.nix derives
      # for everything else.
      url = "${host.name}.${domain}";
      inherit port;
    };

    # Each service's own `virtual-host.homepage.widget.apiKeySecret` (if set) names the age secret
    # holding its API key - collected here rather than hardcoded, so a new API-key widget only
    # needs to set that one field on its own aspect and nothing here has to change.
    # `apiKeyServices` (below) is derived from `virtual-host`, but this field deliberately reads it
    # back out of `config` (set by the `nixos` field, which requests `virtual-host` directly)
    # instead of requesting `virtual-host` here itself. Den's `wrapClassModule` recognizes
    # `virtual-host` as a den context arg (a quirk); once a field mixes a den-recognized arg with a
    # non-recognized one - `secrets` (the self-reference to sibling age secrets, used for
    # `dependencies` below) included - it attaches a collision-validator module whose `warnings`
    # output lands as a literal, ill-typed `age.secrets.warnings` entry (unlike `terranix`'s
    # allowlisted JSON schema, `age.secrets` is a flat `attrsOf submodule` with no room to shim that
    # away - see modules/terranix.nix). `config` and `secrets` are both NOT den-recognized, so
    # requesting them together leaves this field completely unwrapped, delivered via ordinary NixOS
    # `_module.args` instead - safe. This works because the `secrets` class's `nixos`-targeting
    # content is forwarded into the SAME `nixos` evalModules pass (nested under `age.secrets`), so
    # `config.my.homepage-api-key-services` (set below, by the `nixos` field) is visible here too.
    secrets =
      { config, secrets, ... }:
      let
        apiKeyServices = config.my.homepage-api-key-services;
      in
      {
        "homepage-dashboard.env".generator = {
          dependencies = lib.genAttrs (map (vh: vh.homepage.widget.apiKeySecret) apiKeyServices) (name: secrets.${name});
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            lib.concatMapStrings (vh: ''
              printf '${envVarFor vh}="%s"\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.${vh.homepage.widget.apiKeySecret}.file}
              )"
            '') apiKeyServices;
        };
      };

    nixos =
      {
        config,
        virtual-host,
        lib,
        ...
      }:
      let
        urlFor = vh: vh.url or "${vh.name}.${vh.host}.${domain}";
        hosts = lib.listToAttrs (map (vh: lib.nameValuePair vh.name vh) virtual-host);

        homepageServices = lib.filter (vh: vh ? homepage) virtual-host;
        groups = lib.unique (map (vh: vh.homepage.group) homepageServices);
        entryToService =
          vh:
          let
            href = "https://${urlFor vh}";
            widget = vh.homepage.widget or null;
          in
          {
            ${vh.homepage.label} = {
              inherit href;
              inherit (vh.homepage) description;
            }
            // lib.optionalAttrs (widget != null) {
              # Widgets default to the vhost's own href; services behind Authentik forward-auth
              # (e.g. Netdata) override `widget.url` to a direct, unauthenticated address instead.
              # `apiKeySecret` is our own bookkeeping field (see `secrets` above), not a real
              # Homepage widget option - it turns into a `{{HOMEPAGE_VAR_*}}` template reference
              # here instead of being passed through as-is.
              widget = {
                url = href;
              }
              // lib.optionalAttrs (widget ? apiKeySecret) { key = "{{${envVarFor vh}}}"; }
              // removeAttrs widget [ "apiKeySecret" ];
            };
          };
      in
      {
        # Read back by the `secrets` field above, which can't safely request `virtual-host` itself
        # - see the comment there.
        options.my.homepage-api-key-services = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          internal = true;
        };

        config = {
          my.homepage-api-key-services = lib.filter (vh: (vh.homepage.widget.apiKeySecret or null) != null) virtual-host;

          services.homepage-dashboard = {
            enable = true;
            environmentFiles = [ config.age.secrets."homepage-dashboard.env".path ];
            allowedHosts = "localhost:${port'},127.0.0.1:${port'},${urlFor hosts.homepage}";
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
              ${group} = map entryToService (lib.filter (vh: vh.homepage.group == group) homepageServices);
            }) groups;
            bookmarks = [
              {
                "Servers" = [
                  {
                    "Harmony" = [
                      {
                        abbr = "HA";
                        href = "https://${urlFor hosts.homepage}";
                      }
                    ];
                  }
                ];
              }
            ];
          };
        };
      };
  };
}
