{
  my.prowlarr =
    {
      global ? false,
    }:
    { host, ... }:
    let
      # Matches virtual-host.nix's own derived hostname (`${name}.${host.name}.<domain>`) - no
      # shared domain constant exists in this repo (authentik.nix/dns.nix/nginx.nix each carry this
      # same literal), so this matches that convention rather than introducing one.
      domain = "silverlight-nex.us";
      port = 9696;
    in
    {
      nixos = { config, ... }: {
        services = {
          flaresolverr.enable = true;

          prowlarr = {
            enable = true;
            environmentFiles = [ config.age.secrets."prowlarr.env".path ];

            settings = {
              # Prowlarr only reaches this vhost via nginx (its port isn't opened in the
              # firewall), and every such request already passed the Authentik forward-auth gate
              # in front of it - so Prowlarr's own login is pure redundancy.
              # `auth.required = "DisabledForLocalAddresses"` used to paper over that by treating
              # loopback-proxied requests as local, but ASP.NET Core's forwarded-headers
              # middleware rewrites the remote address from nginx's X-Forwarded-For header before
              # that check runs, so "local" actually tracked the real client's address - true from
              # the LAN, false the moment access came from anywhere else, which is why the login
              # started reappearing. `auth.method = "External"` (unlisted in Prowlarr's own UI,
              # but a real, supported value) sidesteps the IP heuristic entirely: Prowlarr treats
              # every request as already authenticated, full stop, leaving Authentik as the sole
              # real gate - matching what this was always supposed to do. `required` is pinned to
              # "Enabled" alongside it (rather than left unset) so nothing falls back to
              # Prowlarr's own persisted config.xml value, which could still be the old
              # "DisabledForLocalAddresses" - it's moot once `method` already authenticates every
              # request, but keeps that heuristic from silently reappearing if it ever weren't.
              auth = {
                method = "External";
                required = "Enabled";
              };

              server = { inherit port; };
            };
          };
        };
      };

      secrets = { secrets, ... }: {
        prowlarr-api-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;

          settings = {
            homepage = "prowlarr";
            terraform = "variable";
          };
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

      # Radarr/Sonarr "Applications" sync, managed via terranix (Nix -> Terraform config, see
      # modules/terranix.nix) and the devopsarr/prowlarr provider - so any indexer added in
      # Prowlarr (still manual for now - see the note below) keeps syncing out to both
      # automatically, instead of that pairing being done by hand in Prowlarr's own UI (Settings >
      # Apps). `sync_level = "addOnly"` only ADDS indexers Prowlarr doesn't yet have configured on
      # the target app - it never removes or edits ones added by hand, so this can't fight a
      # manually-tuned indexer setup on the Radarr/Sonarr side.
      #
      # `RADARR_API_KEY`/`SONARR_API_KEY` are read here as plain resource-attribute values (each
      # target app's OWN API key, which Prowlarr needs as data to authenticate its sync calls) -
      # see radarr.nix's/sonarr.nix's own `terranix` field comments for why those secrets are
      # flagged `settings.terraform = "variable";` rather than left as implicit provider-auth env
      # vars.
      #
      # `sync_categories` are the standard Newznab Movies/TV category groups - adjust if your
      # indexers actually use different ones once those are brought under management (see the
      # `indexers` note below).
      #
      # This resource already exists by hand in the running instance; applying without importing
      # first would create a duplicate (same situation `authentik_outpost.embedded` was in - see
      # authentik.nix's comment on that resource). One-time, per resource, via
      # `nix develop .#<host>-tf` (AUTHENTIK_TOKEN-style env sourcing is automatic, see
      # modules/terranix.nix's `prefixText`):
      #
      #   tofu import prowlarr_application_radarr.radarr <id>                          # GET /api/v1/applications
      #   tofu import prowlarr_application_sonarr.sonarr <id>                          # GET /api/v1/applications
      #   tofu import prowlarr_application_readarr.bookshelf-audiobooks <id>           # GET /api/v1/applications
      #   tofu import prowlarr_application_readarr.bookshelf-ebooks <id>               # GET /api/v1/applications
      #
      # Indexers themselves (`prowlarr_indexer_*`) aren't managed here yet - each of the existing
      # ones needs its own tracker credentials turned into age secrets, and the least error-prone
      # way to get their current config right is importing it from the live instance rather than
      # hand-typing it:
      #
      #   1. Add one `import { to = prowlarr_indexer_x.name; id = "<id>"; }` block per existing
      #      indexer (IDs from `GET /api/v1/indexer`).
      #   2. `tofu plan -generate-config-out=indexers.tf.json` (OpenTofu 1.7+; this repo pins
      #      1.12.3) writes out the actual live resource bodies, credentials included, to a
      #      throwaway file.
      #   3. Hand-port each generated resource into this field, moving credential fields into new
      #      age secrets (`settings.terraform = "variable";`) the same way
      #      discord-client-secret/plex-token work in authentik.nix.
      #   4. Delete the generated file (it holds plaintext credentials) and re-run `tofu plan` to
      #      confirm no diff.
      terranix = { host, ... }: {
        provider.prowlarr = {
          api_key = "\${var.PROWLARR_API_KEY}";
          url = "https://prowlarr.${host.name}.${domain}";
        };

        resource = {
          prowlarr_application_radarr.radarr = {
            api_key = "\${var.RADARR_API_KEY}";
            base_url = "https://radarr.${host.name}.${domain}";
            name = "Radarr";
            prowlarr_url = "https://prowlarr.${host.name}.${domain}";

            sync_categories = [
              2000
              2010
              2020
              2030
              2040
              2045
              2050
              2060
            ];

            sync_level = "addOnly";
          };

          prowlarr_application_readarr = {
            # The two Bookshelf (Readarr) instances - see bookshelf.nix. `sync_categories` differ per
            # instance since each is a single-purpose app, not the usual one-Readarr-does-everything
            # setup: standard Newznab Books categories for the ebook instance, Audio/Audiobook for the
            # audiobook one - adjust either once real indexers are inventoried (see the `indexers` note
            # above).
            bookshelf-audiobooks = {
              api_key = "\${var.BOOKSHELF_AUDIOBOOKS_API_KEY}";
              base_url = "https://bookshelf-audiobooks.${host.name}.${domain}";
              name = "Bookshelf (Audiobooks)";
              prowlarr_url = "https://prowlarr.${host.name}.${domain}";
              sync_categories = [ 3030 ];
              sync_level = "addOnly";
            };

            bookshelf-ebooks = {
              api_key = "\${var.BOOKSHELF_EBOOKS_API_KEY}";
              base_url = "https://bookshelf-ebooks.${host.name}.${domain}";
              name = "Bookshelf (Ebooks)";
              prowlarr_url = "https://prowlarr.${host.name}.${domain}";

              sync_categories = [
                7000
                7010
                7020
                7030
                7040
                7050
                7060
              ];

              sync_level = "addOnly";
            };
          };

          prowlarr_application_sonarr.sonarr = {
            api_key = "\${var.SONARR_API_KEY}";
            base_url = "https://sonarr.${host.name}.${domain}";
            name = "Sonarr";
            prowlarr_url = "https://prowlarr.${host.name}.${domain}";

            sync_categories = [
              5000
              5010
              5020
              5030
              5040
              5045
              5050
              5060
            ];

            sync_level = "addOnly";
          };
        };

        terraform.required_providers.prowlarr = {
          source = "devopsarr/prowlarr";
          version = "~> 3.2";
        };

        variable = {
          BOOKSHELF_AUDIOBOOKS_API_KEY.sensitive = true;
          BOOKSHELF_EBOOKS_API_KEY.sensitive = true;
          # RADARR_API_KEY/SONARR_API_KEY are also declared by radarr.nix/sonarr.nix's own
          # `terranix` fields (for their OWN providers' auth) - redeclared here too, defensively,
          # since both are read as plain resource-attribute values above and this aspect shouldn't
          # depend on include order/completeness elsewhere. Two aspects declaring the same
          # `sensitive = true;` for the same variable merge fine (identical definitions, not a
          # conflict).
          PROWLARR_API_KEY.sensitive = true;
          RADARR_API_KEY.sensitive = true;
          SONARR_API_KEY.sensitive = true;
        };
      };

      virtual-host = {
        inherit global port;

        # Prowlarr serves its own REST API under /api, and proxies per-indexer Torznab requests
        # under /<indexerId>/api; nginx.nix lets both through the Authentik forward-auth gate
        # untouched since cross-seed calls them directly with an API key, machine-to-machine, with
        # no browser session to carry an Authentik cookie.
        bypassAuthPaths = [
          "^/api"
          "^/[0-9]+/api"
        ];

        group = "Arr Stack";

        homepage = {
          description = "Indexer manager/proxy";

          widget = {
            api-key = true;
            type = "prowlarr";
            # Hit Prowlarr directly rather than through nginx/Authentik, since Homepage's
            # server-side widget fetch has no browser session to pass the forward-auth gate.
            url = "http://127.0.0.1:${toString port}";
          };
        };

        host = host.name;
        icon = "prowlarr.svg";
        label = "Prowlarr";
        name = "prowlarr";
        protected = true;
        # Prowlarr's UI keeps a SignalR (WebSocket) connection open for live queue/activity
        # updates - without this, nginx's recommendedProxySettings clears the Connection header
        # (see nginx.nix's `proxyWebsockets` comment) and the upgrade is refused.
        websockets = true;
      };
    };
}
