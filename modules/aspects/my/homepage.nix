{ lib, ... }:
let
  domain = "silverlight-nex.us";
  port = 8082;
  port' = toString port;
  env-var-for = name: "HOMEPAGE_VAR_${lib.toUpper name}_API_KEY";
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
      protected = true;
      inherit port;
    };

    # Each API-key secret names the service it belongs to via its own `settings.homepage` (e.g.
    # sonarr.nix sets `secrets.sonarr-api-key.settings.homepage = "sonarr";`) - collected here by
    # scanning `config.age.secrets` directly, so a new API-key widget only needs that one field on
    # its own secret and nothing here has to change. This sidesteps `virtual-host` entirely: Den's
    # `wrapClassModule` attaches a collision-validator to any field mixing a den-recognized quirk
    # (like `virtual-host`) with a non-recognized arg, and `age.secrets` - a flat `attrsOf
    # submodule` - has no `warnings` option to absorb that validator's output, unlike `terranix`'s
    # allowlisted JSON schema (see modules/terranix.nix). `config`/`secrets` here are both NOT
    # den-recognized, so this field is delivered unwrapped via ordinary NixOS `_module.args` -
    # safe, and simpler than bridging `virtual-host` data through an internal option the way this
    # used to.
    secrets =
      {
        config,
        secrets,
        lib,
        ...
      }:
      let
        # `sec.settings` is a declared option, default `null` - `a.b.c or default` short-circuits
        # the WHOLE chain (not just the last step), so this is safe even when `sec.settings`
        # itself is `null` (see modules/terranix.nix's identical `terraform-mode-of` for the same
        # pattern spelled out further).
        api-key-secrets = lib.filterAttrs (_: sec: sec.settings.homepage or null != null) config.age.secrets;
      in
      {
        # This key's PRESENCE is unconditional (always generated, even if no widget currently sets
        # `api-key`) - a value may safely depend on the fully-merged `config.age.secrets` (used for
        # `api-key-secrets` above), but making the KEY conditional on that same scan would make
        # `config.age.secrets`'s own key set depend on whether THIS module contributes this SAME
        # key - "infinite recursion encountered" (see modules/terranix.nix's identical pattern for
        # the long version of this).
        "homepage-dashboard.env".generator = {
          dependencies = lib.mapAttrs (name: _: secrets.${name}) api-key-secrets;
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            lib.concatMapStrings (name: ''
              printf '${env-var-for api-key-secrets.${name}.settings.homepage}="%s"\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.${name}.file}
              )"
            '') (lib.attrNames api-key-secrets);
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
              # `api-key` is our own bookkeeping flag (see `secrets` above), not a real Homepage
              # widget option - it turns into a `{{HOMEPAGE_VAR_*}}` template reference here
              # instead of being passed through as-is. The env var name is derived purely from
              # `vh.name`, so this doesn't need to know which secret actually backs it.
              widget = {
                url = href;
              }
              // lib.optionalAttrs (widget.api-key or false) { key = "{{${env-var-for vh.name}}}"; }
              // removeAttrs widget [ "api-key" ];
            };
          };
      in
      {
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
}
