let
  domain = "silverlight-nex.us";
in
{
  my.nextcloud =
    {
      global ? false,
    }:
    { host, ... }:
    let
      url = "nextcloud.${host.name}.${domain}";
    in
    {
      dataset = {
        pool = "metalminds";
        name = "nextcloud";
      };

      virtual-host = {
        name = "nextcloud";
        host = host.name;
        inherit global;
        # Deliberately no `port` — Nextcloud is PHP-FPM, not a plain HTTP service to
        # proxy_pass to. The quirk emits only forceSSL/enableACME for this vhost, and
        # Nextcloud's own module below supplies its `locations`/`root`, merging cleanly.
        #
        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Per user_oidc's own callback route (and
        # Authentik's Nextcloud integration guide) - `/index.php/...` only matters for installs
        # that haven't set `overwriteprotocol`-style pretty URLs, which this one has (see
        # `settings.overwriteprotocol` below).
        oidc = {
          redirect-paths = [ "/apps/user_oidc/code" ];
          client-secret = "nextcloud-oidc-client-secret";
        };
        label = "Nextcloud";
        icon = "nextcloud.svg";
        group = "Media";
        homepage = {
          description = "Files, calendar & office suite";
        };
      };

      secrets = {
        nextcloud-admin-password.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 24";
        # `settings.terraform = "variable";` feeds a Terraform `variable` (modules/terranix.nix's
        # two modes); also read directly below (LoadCredential) to configure user_oidc via occ, so
        # it's NOT `intermediary` - it has to be materialized as a real host secret too.
        nextcloud-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          settings.terraform = "variable";
        };
      };

      nixos = { config, pkgs, ... }: {
        services.nextcloud = {
          enable = true;
          hostName = url;
          https = true;
          package = pkgs.nextcloud33;

          database.createLocally = true;
          config = {
            dbtype = "pgsql";
            adminuser = "admin";
            adminpassFile = config.age.secrets.nextcloud-admin-password.path;
          };

          datadir = "/metalminds/nextcloud"; # holds both config/ (config.php) and data/ (user files)

          extraApps = with config.services.nextcloud.package.packages.apps; {
            inherit user_oidc richdocuments;
          };

          settings.overwriteprotocol = "https";
        };

        # Wires user_oidc -> Authentik and richdocuments -> Collabora post-install, since
        # neither app exposes a declarative option surface (both are app-level DB state
        # configured via occ).
        systemd.services.nextcloud-authentik-richdocuments-setup = {
          description = "Configure Nextcloud OIDC (Authentik) and richdocuments (Collabora) via occ";
          after = [
            "nextcloud-setup.service"
            "coolwsd.service"
            "nginx.service"
          ];
          requires = [ "nextcloud-setup.service" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "oneshot";
            User = "nextcloud";
            LoadCredential = "oidc-client-secret:${config.age.secrets.nextcloud-oidc-client-secret.path}";
          };

          path = [ config.services.nextcloud.occ ];

          script = ''
            set -euo pipefail

            # `user_oidc:provider` is an UPSERT keyed on the identifier - its own class is
            # `UpsertProvider`, and it calls `createOrUpdateProvider()` - so it needs no
            # create-vs-update branch. There is no `--update` option (passing one aborts the whole
            # unit before it can correct anything), which is worth stating because getting this
            # wrong FAILS SILENTLY in the worst way: the very first run creates the provider and
            # succeeds, and only later runs - the ones meant to carry a changed `discoveryuri` or a
            # rotated secret into Nextcloud - die, leaving a provider frozen at whatever the first
            # run happened to write. That's exactly how Nextcloud ended up pointing at Authentik's
            # old pre-`global` hostname, which no longer resolves, and reporting only "Could not
            # reach the OpenID Connect provider" at login.
            #
            # `--clientsecret-file` rather than `--clientsecret`: the latter would put the secret in
            # this unit's argv, briefly readable via /proc/<pid>/cmdline by any local user. occ reads
            # and trims the file itself.
            nextcloud-occ user_oidc:provider "authentik" \
              --clientid="nextcloud" \
              --clientsecret-file="$CREDENTIALS_DIRECTORY/oidc-client-secret" \
              --discoveryuri="https://${config.services.authentik.nginx.host}/application/o/nextcloud/.well-known/openid-configuration" \
              --scope="openid email profile"

            nextcloud-occ config:app:set richdocuments wopi_url --value="http://[::1]:9980"
            nextcloud-occ config:app:set richdocuments public_wopi_url --value="https://collabora.${host.name}.${domain}"
            nextcloud-occ config:app:set richdocuments wopi_allowlist --value="::1,127.0.0.1"
          '';
        };
      };
    };
}
