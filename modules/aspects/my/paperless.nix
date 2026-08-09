{ lib, ... }: {
  my.paperless =
    {
      administrators,
      global ? false,
    }:
    { host, ... }:
    let
      url = "paperless.${host.name}.${host.domain}";
    in
    {
      # Owned by Paperless's own native NixOS service user/group (`paperless`, confirmed via
      # `config.services.paperless.user` and its default group of the same name) - zfs.nix's
      # generic `dataset`-quirk consumer chowns it once created, and `units` orders
      # `paperless-secret-key` after that. That one unit is `requiredBy` every other paperless-*
      # service (paperless-web/-consumer/-scheduler/-task-queue), so ordering just it after the
      # dataset transitively covers the rest - same reasoning as nextcloud.nix's own single
      # `nextcloud-setup` entry.
      dataset = {
        # Paperless's documents/thumbnails live in this dataset but its Postgres DB
        # (database.createLocally below, database name "paperless") doesn't - a files-only backup
        # would lose all tags/correspondents/search index without it, so dump it into the dataset
        # right before every backup run and remove the dump again after. Same shape as
        # nextcloud.nix's own DB dump - see its comment for the umask reasoning.
        backup = pkgs: {
          backupCleanupCommand = "rm -f /metalminds/documents/.backup/db.sql";

          backupPrepareCommand = ''
            umask 077
            mkdir -p /metalminds/documents/.backup
            ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump paperless > /metalminds/documents/.backup/db.sql
          '';
        };

        group = "paperless";
        guestAccess = true;
        name = "documents";
        pool = "metalminds";
        samba = true;
        units = [ "paperless-secret-key" ];
        user = "paperless";
      };

      nixos = { config, ... }: {
        services.paperless = {
          enable = true;
          # Points dataDir straight at the mounted dataset (like immich.nix's mediaLocation) -
          # mediaDir/consumptionDir are left at their module defaults, which nest under this as
          # `dataDir/media` and `dataDir/consume`; Paperless creates both itself on first run, same
          # as its own Docker image does with a freshly bind-mounted, empty host directory.
          dataDir = "/metalminds/documents";
          database.createLocally = true;
          # Setting `domain` (rather than `configureNginx`, left at its default `false` since
          # nginx.nix already reverse-proxies every vhost) also sets `PAPERLESS_URL`, which
          # Paperless's own settings module uses to populate CSRF_TRUSTED_ORIGINS/ALLOWED_HOSTS/
          # CORS_ALLOWED_ORIGINS - but only for THIS one origin. That alone would break CSRF for
          # anyone reaching this vhost at its OTHER valid origin, the bare `global` alias
          # (`paperless.${host.domain}`, no `${host.name}.` segment) - Django's CSRF check accepts
          # an Origin that doesn't match CSRF_TRUSTED_ORIGINS as long as it matches
          # `request.scheme + "://" + request.get_host()`, and `get_host()` already correctly
          # reflects whichever hostname was actually used (nginx forwards the real `Host` header
          # unchanged) - but `request.scheme` doesn't, since nginx proxy_passes to Paperless over
          # plain HTTP on loopback and nothing here has told Django that the ORIGINAL request was
          # HTTPS. `PAPERLESS_PROXY_SSL_HEADER` below fixes that generally (any current/future
          # alias), rather than enumerating every hostname into PAPERLESS_CSRF_TRUSTED_ORIGINS by
          # hand - same fix in spirit as nextcloud.nix's own `overwriteprotocol = "https";`.
          domain = url;
          passwordFile = config.age.secrets.paperless-admin-password.path;

          settings = {
            PAPERLESS_ADMIN_USER = lib.head administrators;
            # Authentik is the only way in - nginx.nix's `protected` forward-auth mechanism (this
            # vhost's own `protected = true;` below) sets this exact header on every request that's
            # already passed its auth gate, and Paperless (via Django's RemoteUserMiddleware) trusts
            # it for both the classic Django views and the API the SPA frontend calls, skipping
            # Paperless's own login form entirely. Django's RemoteUserBackend auto-provisions a
            # brand-new, non-admin account for a header value that doesn't match an existing
            # username, so `PAPERLESS_ADMIN_USER` above has to be the exact same string as this
            # person's Authentik username for login to land on the pre-created superuser instead -
            # mirrors immich.nix's identical email-match requirement for its own OIDC login.
            PAPERLESS_ENABLE_HTTP_REMOTE_USER = true;
            PAPERLESS_ENABLE_HTTP_REMOTE_USER_API = true;
            PAPERLESS_HTTP_REMOTE_USER_HEADER_NAME = "HTTP_X_AUTHENTIK_USERNAME";

            # nginx's recommendedProxySettings (nginx.nix) already sends X-Forwarded-Proto: https
            # on every request - this just tells Django (Paperless's own SECURE_PROXY_SSL_HEADER)
            # to trust it, which is what makes `request.is_secure()`/`request.scheme` agree with
            # the browser's real HTTPS Origin. See the comment on `domain` above for why this
            # matters for anything beyond a single hardcoded hostname.
            PAPERLESS_PROXY_SSL_HEADER = [
              "HTTP_X_FORWARDED_PROTO"
              "https"
            ];
          };
        };

        users.users = lib.genAttrs administrators (user: {
          extraGroups = [ "paperless" ];
        });
      };

      secrets.paperless-admin-password.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 24";

      virtual-host = {
        inherit global;
        group = "Media";
        homepage.description = "Document scanning & OCR archive";
        host = host.name;
        icon = "paperless-ngx.svg";
        label = "Paperless-ngx";
        name = "paperless";
        port = 28981;
        protected = true;
        # Paperless's frontend opens a WebSocket for live document-processing status updates -
        # without this, nginx's recommendedProxySettings clears the Connection header (see
        # nginx.nix's `proxyWebsockets` comment) and the upgrade is refused.
        websockets = true;
      };
    };
}
