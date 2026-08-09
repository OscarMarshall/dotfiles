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
          settings.terraform = true;
        };

        # Not consumed yet (see the `terranix`/`virtual-host` comments below on why the OIDC wiring
        # itself is deferred) - declared now so `agenix generate -a && agenix rekey -a` only needs
        # running once, covering both this and `jellyfin-api-key` in the same pass.
        jellyfin-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = "variable";
        };
      };

      terranix = { host, ... }: {
        provider.jellyfin.endpoint = "https://jellyfin.${host.name}.${host.domain}";

        resource = {
          jellyfin_plugin = {
            fanart = {
              name = "Fanart";
              repository_url = officialManifestUrl;
            };

            intro_skipper = {
              name = "Intro Skipper";
              repository_url = introSkipperManifestUrl;
            };

            moonbase = {
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
            sso_authentication = {
              name = "SSO Authentication";
              repository_url = ssoAuthManifestUrl;
            };
          };

          # No `provider "authentik"`-side resources here (that's authentik.nix's own `oidc-hosts`
          # consumer, driven by `virtual-host.oidc` below) or `jellyfin_plugin_configuration` for
          # the SSO Authentication plugin yet - both would reference
          # `${var.JELLYFIN_OIDC_CLIENT_SECRET}`, and `jellyfin-oidc-client-secret` is still an
          # ungenerated placeholder. Learned this the hard way with `jellyfin-api-key` earlier in
          # this same PR: EVERY resource in a `tofu plan` has to succeed for ANY of them to apply -
          # a plugin_configuration referencing an undefined variable would fail the whole apply,
          # including totally unrelated resources (DNS records, other hosts' secrets, etc.), not
          # just this one. Add the `oidc` block back to `virtual-host` below and a
          # `jellyfin_plugin_configuration.sso_authentication` resource (OidConfigs.authentik =
          # { OidEndpoint = "https://auth.${host.domain}/application/o/jellyfin/"; OidClientId =
          # "jellyfin"; OidSecret = "\${var.JELLYFIN_OIDC_CLIENT_SECRET}"; Enabled = true;
          # EnableAuthorization = false; EnableAllFolders = true; }, referencing
          # `plugin_id = "\${jellyfin_plugin.sso_authentication.id}"`) once `agenix generate -a &&
          # agenix rekey -a` has actually run.
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
        homepage.description = "Media server";
        host = host.name;
        icon = "jellyfin.svg";
        label = "Jellyfin";
        name = "jellyfin";

        # No `oidc` block yet - see the `terranix` field's comment above on why the SSO
        # Authentication plugin's config is deferred until `jellyfin-oidc-client-secret` is a real
        # value. Once it is, add: `oidc = { client-secret = "jellyfin-oidc-client-secret";
        # redirect-paths = [ "/sso/OID/redirect/authentik" ]; };` (the SSO Authentication plugin
        # handles its own OIDC login - github.com/9p4/jellyfin-plugin-sso/blob/main/providers.md -
        # so this is `oidc`, a native application, rather than `protected`/forward-auth; see
        # virtual-host.nix's own comment on the two being mutually exclusive).
      };
    };
}
