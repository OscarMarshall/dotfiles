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
      # 9p4/jellyfin-plugin-sso (the original) was archived 2026-05-12 and never shipped a
      # Jellyfin 12-compatible build (its manifest tops out at targetAbi 10.11.0.0) - confirmed via
      # github.com/9p4/jellyfin-plugin-sso/issues/315 and /307, which is exactly the symptom here:
      # the plugin loads as "NotSupported" against a 12.x server, so Jellyfin silently drops its
      # login-page integration and the SSO button disappears. Flowfin/jellyfin-plugin-sso (mirrored
      # under other forks, e.g. kernicek/jellyfin-plugin-sso) is a maintained continuation that
      # KEPT THE SAME PLUGIN GUID (505ce9d1-d916-42fa-86ca-673ef241d7df) and targets both 10.11
      # (.NET 9) and 12.0 (.NET 10) from one manifest - a true drop-in that installs over the
      # existing plugin and keeps `jellyfin_plugin_configuration.sso_authentication` below intact.
      # `manifest-beta` (not a `-release` branch) is not a caveat here - it's currently the only
      # branch publishing a 12.0.0.0-targetAbi build at all.
      ssoAuthManifestUrl = "https://raw.githubusercontent.com/Flowfin/jellyfin-plugin-sso/manifest-beta/manifest.json";
    in
    {
      nixos = { pkgs, ... }: {
        # UHD 770 (Raptor Lake iGPU, harmony's i9-13900K) - intel-media-driver (iHD) is Intel's
        # recommended VAAPI driver for Broadwell and newer.
        hardware.graphics = {
          enable = true;
          extraPackages = [ pkgs.intel-media-driver ];
        };

        services = {
          # No `openFirewall`/`port-forward` (unlike plex.nix): Plex genuinely wants direct inbound
          # reachability for its own remote-access/relay-avoidance logic, but Jellyfin has no such
          # requirement - it's reached exclusively through nginx's loopback proxy_pass, same as
          # Sonarr/Radarr/Prowlarr (see sonarr.nix's own comment on this). Opening 8096 - a plaintext
          # HTTP port, since TLS termination happens at nginx - on the LAN firewall or WAN via Meraki
          # would just be unnecessary attack surface with no upside.
          jellyfin = {
            enable = true;

            hardwareAcceleration = {
              enable = true;
              device = "/dev/dri/renderD128";
              type = "vaapi";
            };

            transcoding.enableHardwareEncoding = true;
          };

          # The SSO plugin's post-login hand-off embeds the real Jellyfin web client in an iframe on
          # its own callback page (same origin - both served by Jellyfin itself) and waits for it to
          # load ("Still waiting for the Jellyfin web client ... to start inside this page" if it
          # never does). nginx.nix's `appendHttpConfig` sends `X-Frame-Options DENY` for every vhost
          # unconditionally, which blocks ALL framing, including same-origin - confirmed live: the
          # SSO login itself completed fine server-side (`[SSO Audit] Login succeeded`ed in
          # Jellyfin's own log), only the client-side iframe hand-off hung. `SAMEORIGIN` instead of
          # `DENY`, for this vhost only - same override mechanism authentik.nix uses for its own
          # CSRF-cookie quirk (`nginx.virtualHosts.${url}.extraConfig`), bypassing the `virtual-host`
          # quirk system since this is Jellyfin-specific, not something every service needs. Re-
          # declares the other three headers alongside it (not just `X-Frame-Options` on its own) -
          # nginx only inherits `appendHttpConfig`'s `add_header`s into a vhost that declares NONE of
          # its own; declaring even one here means declaring all of them, same reasoning as
          # nginx.nix's own `securityHeaders` string.
          nginx.virtualHosts."jellyfin.${host.name}.${host.domain}".extraConfig = ''
            add_header Strict-Transport-Security $hsts_header;
            add_header 'Referrer-Policy' 'origin-when-cross-origin';
            add_header X-Frame-Options SAMEORIGIN;
            add_header X-Content-Type-Options nosniff;
          '';
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

        # Fed into the `moonbase` `jellyfin_plugin_configuration`'s `SeerrWebhookSecret` below - the
        # shared secret Seerr must present (as a query param) when it calls Moonbase's own webhook.
        # `intermediary`: only ever consumed as a Terraform `variable` inside this same file, unlike
        # `jellyfin-api-key` above (also read by homepage.nix) or `seerr-oidc-client-secret`
        # (seerr.nix, also `LoadCredential`ed into its own systemd unit).
        moonfin-seerr-webhook-secret = {
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
            #
            # Moonbase's own Seerr integration is configured below via `jellyfin_plugin_configuration.
            # moonbase` (its own comment covers the full-replacement `configuration_json` hazard).
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
            # plugin: SSO-Auth 4.0.0.4"), the LOADED plugin is registered under its own
            # assembly/project name ("SSO-Auth"), not the manifest's friendly `name` (which is what
            # actually installs it - "SSO Authentication" on the archived 9p4 manifest, now
            # "Community SSO for Jellyfin" on `ssoAuthManifestUrl`'s Flowfin replacement, see that
            # variable's own comment). `name` forces replacement on any mismatch, which without this
            # would destroy and recreate an already-working, correctly-installed plugin every single
            # apply - "no value here avoids this, the state itself is wrong", same class of bug as
            # `library_options` above.
            sso_authentication = {
              depends_on = [ "jellyfin_plugin_repository.sso-auth" ];
              lifecycle.ignore_changes = [ "name" ];
              name = "Community SSO for Jellyfin";
              repository_url = ssoAuthManifestUrl;
            };
          };

          jellyfin_plugin_configuration = {
            # Establishes Moonbase's ENTIRE stored config (not just its Seerr integration) on first
            # apply: the provider's own `UpdatePluginConfiguration` (client/plugins.go) does a raw POST
            # of `configuration_json` straight to Jellyfin's `/Plugins/{id}/Configuration`, which
            # Jellyfin core deserializes onto a BRAND NEW config object - any field left out here would
            # revert to Moonfin-Client/Plugin's own C# class default, same as `library_options`/
            # `sso_authentication`'s `configuration_json` are full replacements, not merges. Every field
            # below mirrors `Jellyfin/backend/PluginConfiguration.cs` (Moonfin-Client/Plugin@3908c9f,
            # 2026-09) at its own stock default EXCEPT the `Seerr*`/`PublicServerUrl` block, which wires
            # up `seerr` (seerr.nix). Re-diff against that file whenever Moonfin materially changes.
            #
            # `lifecycle.ignore_changes = [ "configuration_json" ]`: the SAME confirmed provider/
            # Terraform-core bug `sso_authentication` below already hit ("Provider produced inconsistent
            # result after apply ... .configuration_json: inconsistent values for sensitive attribute"),
            # now also confirmed live here - same round-trip-through-Jellyfin's-own-store mechanism, just
            # applied to a much larger payload. Without this, every apply after the first retries - and
            # fails - identically, forever. This DOES mean the "own the entire plugin going forward"
            # framing above only holds through the first successful apply: after that, Terraform never
            # touches this field again, and any setting an admin later changes via Dashboard -> Plugins
            # -> Moonfin (a custom theme upload, a server message, an anime-markers toggle, the Seerr
            # fields themselves, ...) sticks - same tradeoff `sso_authentication` already lives with.
            moonbase = {
              configuration_json = builtins.toJSON {
                AnimeAudioMarkersEnabled = false;
                AnimeAudioMarkersMovies = false;
                AnimeAudioSeparateDualAudio = false;
                AnimeAudioTrustSelectedLibraries = false;
                AnimeMarkerLibraryIds = [ ];
                AnimeMarkerMaxAgeDays = 30;
                AnimeMarkerPlacement = "below";
                AnimeMarkerRecapLookup = true;
                AnimeMarkerShowAnimeCanon = false;
                AnimeMarkerShowFiller = true;
                AnimeMarkerShowMangaCanon = false;
                AnimeMarkerShowMixed = true;
                AnimeMarkerShowRecap = true;
                AnimeMarkerVerboseLogging = false;
                AnimeMarkersEnabled = false;
                DefaultUserSettings = null;
                EnableSettingsSync = true;
                FcmServiceAccountJson = null;
                FcmServiceAccountPath = null;
                GameLibraryIds = [ ];
                GamesCoreDataUrl = null;
                GamesCoreZipUrl = null;
                GamesEnabled = false;
                GamesIsolateWebApp = false;
                GamesLaunchBoxEnabled = true;
                GamesLaunchBoxUrl = "https://gamesdb.launchbox-app.com/Metadata.zip";
                GamesMetadataDbUrlBase = "https://cdn.jsdelivr.net/gh/libretro/libretro-database@master/rdb/";
                GamesMetadataEnabled = true;
                ImdbListsEnabled = true;
                MdblistApiKey = null;
                MdblistOfficialListsEnabled = true;
                MdblistOfficialListsMaxItems = 250;
                Messages = [ ];
                # Loopback again (Jellyfin's own `port` above): the base URL Seerr's webhook call
                # targets back at Moonbase, resolved deterministically instead of leaving it to
                # Moonbase's own published-URL/LAN-IP-enumeration fallback chain.
                PublicServerUrl = "http://127.0.0.1:${toString port}";
                PushRelayAppKey = null;
                PushRelayUrl = "https://push.moonfin.io/send";
                RecommendationsProviderEnabled = true;
                SeerrDisplayName = null;
                SeerrEnabled = true;
                # seerr.nix's own `port` (5055); loopback since `seerr` and Jellyfin both run natively
                # on the same host - same reasoning as this file's own homepage widget `url` above.
                SeerrUrl = "http://127.0.0.1:5055";
                # Auto-registers Moonbase's webhook in Seerr (via an admin's own Seerr session, once
                # they've signed in through a Moonfin client) - no admin API key to mint and paste by
                # hand, unlike this file's own top-of-file `jellyfin-api-key` note.
                SeerrWebhookSecret = "\${var.MOONFIN_SEERR_WEBHOOK_SECRET}";
                StudioLogosEnabled = true;
                StudioLogosMaxAgeDays = 30;
                TmdbApiKey = null;
                UploadedThemes = [ ];
                WebDefaultServerUrl = null;
                WebEnableWebRtcScan = true;
                WebForcedServerUrl = null;
              };

              lifecycle.ignore_changes = [ "configuration_json" ];
              plugin_id = "\${jellyfin_plugin.moonbase.id}";
            };

            sso_authentication = {
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
                # Plugin-wide (NOT per-provider, unlike everything under `OidConfigs.authentik`
                # below) - off by default, "fail safe": without it, an enabled/working provider
                # still never gets a button spliced into the login page's branding disclaimer.
                # Confirmed live: `Test Connection` succeeding was NOT enough on its own - the
                # button was still absent from the login page until this was also turned on.
                ManageLoginPageButtons = true;

                OidConfigs.authentik = {
                  # The SSO plugin's outbound fetches (discovery, JWKS, token, userinfo, back-channel
                  # logout) refuse a target that resolves to a private-network address by default (an
                  # SSRF/DNS-rebind guard) - and `auth.${host.domain}` does, on-box: authentik.nix's
                  # own `networking.hosts` pins it to harmony's LAN IP so on-box callers don't hit the
                  # SAME hostname's public AAAA record, which is unreachable from harmony itself (see
                  # that pin's own comment). Confirmed live: without this, every fetch failed fast with
                  # "The outbound host resolves only to blocked addresses" instead of the earlier
                  # (pre-`networking.hosts`) 10s hang. Scoped to just this provider, not a global
                  # toggle - the guard is per-provider by design.
                  AllowPrivateNetworkAddresses = true;
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
        };

        # Not auto-declared the way every `virtual-host.oidc.client-secret` is (authentik.nix's own
        # `genAttrs ... oidc-hosts` collects those centrally) - `moonfin-seerr-webhook-secret` has
        # nothing to do with Authentik/OIDC, so per modules/terranix.nix's own header comment, THIS
        # aspect (the one actually consuming it, below) is the one that has to declare it.
        variable.MOONFIN_SEERR_WEBHOOK_SECRET.sensitive = true;
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
            # Jellyfin 10.12+ (now packaged as 12.0 in nixpkgs) deprecated the v1 widget API -
            # see https://gethomepage.dev/widgets/services/jellyfin/.
            version = 2;
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
