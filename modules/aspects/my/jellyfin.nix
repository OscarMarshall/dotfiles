# Plugin installation is managed via terranix (Nix -> Terraform config, see modules/terranix.nix)
# and the ThePhaseless/jellyfin provider (registry.terraform.io/providers/ThePhaseless/jellyfin) -
# unlike Sonarr/Radarr/Prowlarr's own providers, this one can't authenticate with a key we generate
# ourselves: Jellyfin only ever issues API keys itself, to an already-authenticated session, so
# there's no equivalent of those aspects' generated `*-api-key` secret pushed into the app's own
# config on first start.
#
# One-time manual setup, after Jellyfin's own first-run wizard has created an admin account:
# Dashboard -> API Keys -> "+" to mint one, then `agenix edit secrets/jellyfin-api-key.age` (needs
# the YubiKey) to store it, and `agenix rekey -a` to make it available to harmony. The provider
# reads it from the JELLYFIN_API_KEY env var (`settings.terraform = true;` below), same mechanism as
# the Cloudflare/Meraki providers (dns.nix/meraki.nix) - never written into the generated Terraform
# config or state.
{
  my.jellyfin =
    {
      global ? false,
    }:
    { host, ... }:
    let
      introSkipperManifestUrl = "https://intro-skipper.org/manifest.json";
      moonfinManifestUrl = "https://raw.githubusercontent.com/Moonfin-Client/Plugin/refs/heads/master/manifest.json";
      officialManifestUrl = "https://repo.jellyfin.org/files/plugin/manifest.json";
      port = 8096;
      ssoAuthManifestUrl = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json";
    in
    {
      nixos = { pkgs, ... }: {
        # UHD 770 (Raptor Lake iGPU, harmony's i9-13900K) - intel-media-driver (iHD) is Intel's
        # recommended VAAPI driver for Broadwell and newer.
        hardware.graphics = {
          enable = true;
          extraPackages = [ pkgs.intel-media-driver ];
        };

        # No `openFirewall`/`port-forward` (unlike plex.nix): Plex genuinely wants direct inbound
        # reachability for its own remote-access/relay-avoidance logic, but Jellyfin has no such
        # requirement - it's reached exclusively through nginx's loopback proxy_pass, same as
        # Sonarr/Radarr/Prowlarr (see sonarr.nix's own comment on this). Opening 8096 - a plaintext
        # HTTP port, since TLS termination happens at nginx - on the LAN firewall or WAN via Meraki
        # would just be unnecessary attack surface with no upside.
        services.jellyfin = {
          enable = true;

          hardwareAcceleration = {
            enable = true;
            device = "/dev/dri/renderD128";
            type = "vaapi";
          };

          transcoding.enableHardwareEncoding = true;
        };
      };

      secrets = {
        jellyfin-api-key = {
          intermediary = true;
          rekeyFile = ../../../secrets/jellyfin-api-key.age;

          settings = {
            homepage = "jellyfin";
            terraform = true;
          };
        };

        # Shared between authentik.nix's own `authentik_provider_oauth2` (fed via the `oidc` field
        # below) and the `jellyfin_plugin_configuration` resource's `OidSecret` - both sides of the
        # same OIDC handshake need the identical value, which is exactly what referencing the same
        # `settings.terraform = "variable"` secret from two different `terranix` fields gets for
        # free (see seerr.nix's own `seerr-oidc-client-secret` for the same pattern).
        jellyfin-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = "variable";
        };
      };

      terranix = { host, ... }: {
        provider.jellyfin.endpoint = "https://jellyfin.${host.name}.${host.domain}";

        resource = {
          # Names/paths are a best-effort guess (Radarr's/Sonarr's own `movies`/`shows` datasets -
          # radarr.nix/sonarr.nix), confirmed against reality via `tofu import` (movies -> "Movies",
          # tv-shows -> "Shows" - NOT "TV Shows", the first guess).
          #
          # `library_options` has TWO confirmed, compounding provider bugs, not just one:
          #   1. Omitting the attribute entirely crashes on CREATE ("Value Conversion Error ...
          #      Received unknown value, however the target type cannot handle unknown values").
          #   2. Declaring it (any value) crashes on UPDATE once imported: the provider's own
          #      `Read` never populates 8 of its 15 fields into state, so they show up as "+"
          #      (addition) in every `tofu plan` regardless of what's declared here - and the
          #      resulting `UpdateLibraryOptions` API call fails server-side with `Guid can't be
          #      empty (Parameter 'id')` (confirmed in Jellyfin's own logs: the provider isn't
          #      threading the library's internal item GUID through the update request). There's no
          #      value to pick here that avoids this - state is structurally incomplete, so an
          #      update gets attempted (and fails) every single apply.
          # `lifecycle.ignore_changes` on `library_options` below is the actual fix: Terraform stops
          # diffing/updating that field entirely after this one-time import, sidestepping bug #2
          # completely. The values themselves matter only for the CREATE path (a fresh, not-yet-
          # imported library, where bug #1 still applies) - which won't happen again for these two,
          # already-imported resources, but keeps a third jellyfin_library added later from hitting
          # bug #1 on its own first apply.
          jellyfin_library =
            let
              stockDefaults = {
                cache_images_in_library = false;
                disabled = false;
                download_images_in_advance = false;
                enable_chapter_image_extraction = true;
                enable_photos = true;
                enable_realtime_monitor = true;
                extract_chapters_during_library_scan = false;
                extract_media_information_during_library_scan = true;
                import_missing_episodes = false;
                metadata_country_code = "US";
                metadata_refresh_mode = "Default";
                preferred_metadata_language = "en";
                save_local_metadata = true;
                save_local_thumbnail_sets = false;
                season_zero_display_name = "Specials";
              };
            in
            {
              movies = {
                collection_type = "movies";
                library_options = stockDefaults;
                lifecycle.ignore_changes = [ "library_options" ];
                name = "Movies";
                paths = [ "/metalminds/movies" ];
              };

              tv-shows = {
                collection_type = "tvshows";
                library_options = stockDefaults;
                lifecycle.ignore_changes = [ "library_options" ];
                name = "Shows";
                paths = [ "/metalminds/shows" ];
              };
            };

          # `depends_on` on every THIRD-PARTY plugin (repository_url isn't a resource reference -
          # it's a plain string, giving Terraform no implicit ordering against the matching
          # `jellyfin_plugin_repository` below) - confirmed live: without it, Terraform created a
          # repository and tried installing its plugin in the same parallel apply, and Jellyfin's
          # own package catalog hadn't picked up the brand-new repository yet ("GET /Packages
          # returned status 500", "No package named X found ... register the plugin repository
          # first"). Fanart/Open Subtitles don't need this - they resolve against Jellyfin's own
          # pre-registered official repository, not one this config creates.
          jellyfin_plugin = {
            fanart = {
              name = "Fanart";
              repository_url = officialManifestUrl;
            };

            intro_skipper = {
              depends_on = [ "jellyfin_plugin_repository.intro-skipper" ];
              name = "Intro Skipper";
              repository_url = introSkipperManifestUrl;
            };

            # `lifecycle.ignore_changes`: Jellyfin registers a LOADED plugin under its own
            # assembly/project name, which can differ from the "friendly" name its manifest
            # advertises for catalog installs - confirmed live in Jellyfin's own logs ("Loaded
            # assembly Moonfin.Server ... Loaded plugin: Moonfin 2.0.3.0"), even though the
            # Moonfin repository's manifest, and the install call that actually worked, both call
            # it "Moonbase". Both `name` and `repository_url` force replacement on any mismatch,
            # and neither one is populated correctly by `tofu import` (which is how this resource
            # ended up in state after the plain `apply` path got stuck in an endless
            # install-always-needs-a-restart loop against the WRONG name) - same "no value here
            # avoids this" class of bug as `sso_authentication` below and `library_options` above.
            moonbase = {
              depends_on = [ "jellyfin_plugin_repository.moonfin" ];

              lifecycle.ignore_changes = [
                "name"
                "repository_url"
              ];

              name = "Moonbase";
              repository_url = moonfinManifestUrl;
            };

            open_subtitles = {
              name = "Open Subtitles";
              repository_url = officialManifestUrl;
            };

            # `EnableAuthorization = false;`/`EnableAllFolders = true;` (no RBAC): mapping
            # authentik groups to Jellyfin roles needs a custom "Group Membership" Authentik scope
            # mapping (github.com/9p4/jellyfin-plugin-sso/blob/main/providers.md#authentik) that
            # authentik.nix's generic `oidc` field doesn't set up - every authenticated Authentik
            # user just gets a normal (non-admin) account with full library access, which is fine
            # for a family server. Revisit if finer-grained access ever matters.
            #
            # `lifecycle.ignore_changes = [ "name" ]`: same root cause as `moonbase`'s own comment
            # above - confirmed in Jellyfin's own logs ("Loaded assembly SSO-Auth ... Loaded
            # plugin: SSO-Auth 4.0.0.4"), the LOADED plugin is registered as "SSO-Auth" (its
            # assembly/project name), not "SSO Authentication" (the manifest's friendly name, and
            # what actually installs it). `name` forces replacement on any mismatch, which without
            # this would destroy and recreate an already-working, correctly-installed plugin every
            # single apply - "no value here avoids this, the state itself is wrong", same class of
            # bug as `library_options` above.
            sso_authentication = {
              depends_on = [ "jellyfin_plugin_repository.sso-auth" ];
              lifecycle.ignore_changes = [ "name" ];
              name = "SSO Authentication";
              repository_url = ssoAuthManifestUrl;
            };
          };

          jellyfin_plugin_configuration.sso_authentication = {
            # `\${...}` (not a plain Nix interpolation) - Terraform's JSON syntax interpolates
            # `${...}` sequences found ANYWHERE inside a string attribute, including ones nested a
            # level deep inside another string (`OidSecret`'s value here) - so this one substring
            # gets replaced with the real secret at apply time while the rest of the
            # `builtins.toJSON`-rendered document around it is passed through as literal text.
            #
            # `lifecycle.ignore_changes = [ "configuration_json" ]`: yet another provider bug, this
            # time Terraform's own core catching it rather than Jellyfin's API - confirmed live,
            # every single apply attempt (3 retries, all identical): "Provider produced
            # inconsistent result after apply ... .configuration_json: inconsistent values for
            # sensitive attribute ... This is a bug in the provider" (Terraform's own error text).
            # The update request itself does reach Jellyfin - `/sso/OID/{start,redirect}/authentik`
            # both return 400 (a recognized provider slug rejecting a bare unauthenticated request),
            # not 404 (an unrecognized one) - but the provider's `Update` then reports back a
            # DIFFERENT `configuration_json` string than what was sent, most likely because Jellyfin
            # round-trips this plugin's config through its own XML-backed store and re-serializes it
            # differently on read-back. Since Terraform's consistency check fails the WHOLE
            # operation (not just a warning) and never commits the update to state, every apply
            # would retry - and fail - this identical step forever without this.
            configuration_json = builtins.toJSON {
              OidConfigs.authentik = {
                EnableAllFolders = true;
                EnableAuthorization = false;
                Enabled = true;
                OidClientId = "jellyfin";
                # Matches authentik.nix's own `url = if global then "auth.${host.domain}" ...`
                # (Authentik is deployed `global = true` on harmony) - can't read
                # `config.services.authentik.nginx.host` directly the way immich.nix/nextcloud.nix/
                # seerr.nix do, since that's a NixOS `config` value and `terranix` is evaluated
                # through a completely separate module system with no access to it.
                OidEndpoint = "https://auth.${host.domain}/application/o/jellyfin/";
                OidSecret = "\${var.JELLYFIN_OIDC_CLIENT_SECRET}";
              };
            };

            lifecycle.ignore_changes = [ "configuration_json" ];
            plugin_id = "\${jellyfin_plugin.sso_authentication.id}";
          };

          jellyfin_plugin_repository = {
            intro-skipper = {
              enabled = true;
              name = "Intro Skipper";
              url = introSkipperManifestUrl;
            };

            moonfin = {
              enabled = true;
              name = "Moonfin";
              url = moonfinManifestUrl;
            };

            sso-auth = {
              enabled = true;
              name = "SSO-Auth";
              url = ssoAuthManifestUrl;
            };
          };
        };

        terraform.required_providers.jellyfin = {
          # Full hostname required: unlike the devopsarr/goauthentik/etc. providers elsewhere in
          # this repo, ThePhaseless/jellyfin is only published to registry.terraform.io (Hashicorp's
          # registry) - OpenTofu's own default registry.opentofu.org doesn't mirror it, and a bare
          # "ThePhaseless/jellyfin" source resolves against that default, not terraform.io.
          source = "registry.terraform.io/ThePhaseless/jellyfin";
          version = "~> 0.3";
        };
      };

      virtual-host = {
        inherit global port;
        group = "Media";

        homepage = {
          description = "Media server";

          widget = {
            api-key = true;
            enableBlocks = true;
            enableUser = true;
            showEpisodeNumber = true;
            type = "jellyfin";
            # Hit Jellyfin directly rather than through nginx, since Homepage's server-side widget
            # fetch has no browser session to carry anything the SSO Authentication plugin might
            # otherwise care about (see sonarr.nix's own comment on the same pattern).
            url = "http://127.0.0.1:${toString port}";
            # `version = 2;` once harmony's Jellyfin is upgraded past 10.12 (currently 10.11.x) -
            # see https://gethomepage.dev/widgets/services/jellyfin/.
          };
        };

        host = host.name;
        icon = "jellyfin.svg";
        label = "Jellyfin";
        name = "jellyfin";

        # The SSO Authentication plugin handles its own OIDC login (redirect path is the plugin's
        # own convention, github.com/9p4/jellyfin-plugin-sso/blob/main/providers.md), so this is
        # `oidc` (a native application) rather than `protected` (forward-auth) - see
        # virtual-host.nix's own comment on the two being mutually exclusive.
        oidc = {
          client-secret = "jellyfin-oidc-client-secret";
          redirect-paths = [ "/sso/OID/redirect/authentik" ];
        };

        # Jellyfin's web client keeps a WebSocket open to `/socket` for real-time features (now
        # playing, remote control, SyncPlay) - without this, nginx's recommendedProxySettings
        # clears the Connection header (see nginx.nix's own `proxyWebsockets` comment, and
        # sonarr.nix's identical situation with its SignalR connection) and the upgrade is refused.
        websockets = true;
      };
    };
}
