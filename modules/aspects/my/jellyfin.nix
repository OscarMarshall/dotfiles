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
#
# The actual `provider "jellyfin" {}` block and its resources (plugin repo + Moonbase install) are
# deliberately NOT declared yet, even though `jellyfin-api-key` and `required_providers.jellyfin`
# are - every declared provider gets configured during `tofu plan` regardless of whether any
# resource references it, and this one doesn't yet have a real API key (still a
# harmless-but-invalid `settings.terraform = true;` placeholder). A `tofu plan` that fails to
# configure/authenticate ANY provider fails the whole apply - including totally unrelated
# resources, like the Cloudflare DNS record this vhost's ACME order needs (#657's first go at this
# hit exactly that: one broken provider took down DNS record creation with it). Add the provider
# block + `jellyfin_plugin`/`jellyfin_plugin_repository` resources back (see PR #657 history for the
# exact shape) once the real key is in place.
{
  my.jellyfin =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 8096;
    in
    {
      nixos = { pkgs, ... }: {
        # UHD 770 (Raptor Lake iGPU, harmony's i9-13900K) - intel-media-driver (iHD) is Intel's
        # recommended VAAPI driver for Broadwell and newer.
        hardware.graphics = {
          enable = true;
          extraPackages = [ pkgs.intel-media-driver ];
        };

        services.jellyfin = {
          enable = true;

          hardwareAcceleration = {
            enable = true;
            device = "/dev/dri/renderD128";
            type = "vaapi";
          };

          openFirewall = true;
          transcoding.enableHardwareEncoding = true;
        };
      };

      port-forward = {
        inherit port;
        name = "jellyfin";
      };

      secrets.jellyfin-api-key = {
        intermediary = true;
        rekeyFile = ../../../secrets/jellyfin-api-key.age;
        settings.terraform = true;
      };

      terranix.terraform.required_providers.jellyfin = {
        # Full hostname required: unlike the devopsarr/goauthentik/etc. providers elsewhere in
        # this repo, ThePhaseless/jellyfin is only published to registry.terraform.io (Hashicorp's
        # registry) - OpenTofu's own default registry.opentofu.org doesn't mirror it, and a bare
        # "ThePhaseless/jellyfin" source resolves against that default, not terraform.io.
        source = "registry.terraform.io/ThePhaseless/jellyfin";
        version = "~> 0.3";
      };

      virtual-host = {
        inherit global port;
        group = "Media";
        homepage.description = "Media server";
        host = host.name;
        icon = "jellyfin.svg";
        label = "Jellyfin";
        name = "jellyfin";
      };
    };
}
