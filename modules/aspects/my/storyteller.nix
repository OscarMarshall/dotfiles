let
  domain = "silverlight-nex.us";
in
{
  my.storyteller =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 8001;

      # Like authentik.nix's own `url` (and unlike every other service's `global`, which merely adds
      # an ALIAS alongside the host-scoped name - see virtual-host.nix), `global` here SWITCHES the
      # served hostname rather than adding to it. Storyteller pins its session cookie's `Domain` to
      # whatever hostname `AUTH_URL` names (see `AUTH_URL` below), and
      # `storyteller.${host.name}.${domain}` is NOT a subdomain of `storyteller.${domain}` - so a
      # browser on the name AUTH_URL doesn't cover would reject the session cookie and silently loop
      # back to the login page. One name has to be canonical; serving the other would just be a trap.
      url = if global then "storyteller.${domain}" else "storyteller.${host.name}.${domain}";
    in
    {
      dataset = {
        name = "storyteller";
        pool = "metalminds";
      };

      nixos = { config, ... }: {
        virtualisation.oci-containers.containers.storyteller = {
          environment = {
            # Storyteller's Auth.js base URL: its own origin plus Auth.js's `basePath`. Required for
            # OAuth/OIDC login, and what its session cookie's `Domain` is pinned to - see `url`
            # above for why that forces a single canonical hostname.
            AUTH_URL = "https://${url}/api/v2/auth";
            ENABLE_WEB_READER = "true";
          };

          environmentFiles = [ config.age.secrets."storyteller.env".path ];
          # Pinned to the current `latest` tag's digest at the time this was written --
          # storyteller-platform doesn't cut stable releases, so there's nothing more specific to
          # pin to. Re-resolve via the GitLab registry API if bumping:
          #   curl -s "https://gitlab.com/api/v4/projects/67994333/registry/repositories/8429296/tags/latest"
          image = "registry.gitlab.com/storyteller-platform/storyteller@sha256:a15609ec102de6aace73b5aae3794f7f8e9f40ed3ac2f57e923ef72daa505668";

          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];

          volumes = [ "/metalminds/storyteller:/data" ];
        };
      };

      secrets = { secrets, ... }: {
        # `intermediary` (unlike immich/nextcloud/seerr's equivalents, which are NOT) - Storyteller
        # keeps its OIDC provider config in its own settings DATABASE, entered through the settings
        # UI, with no env-var or config-file equivalent to point at a decrypted secret. So nothing
        # on the host ever reads this; it exists only to feed Authentik's side via a Terraform
        # `variable` (modules/terranix.nix's two modes), and gets typed into Storyteller by hand -
        # read it back with `agenix view secrets/generated/storyteller-oidc-client-secret.age`.
        storyteller-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = "variable";
        };

        storyteller-secret-key = {
          generator.script = "alnum";
          intermediary = true;
        };

        "storyteller.env".generator = {
          dependencies = { inherit (secrets) storyteller-secret-key; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'STORYTELLER_SECRET_KEY="%s"\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.storyteller-secret-key.file}
              )"
            '';
        };
      };

      virtual-host = {
        inherit global port url;
        group = "Media";

        homepage = {
          description = "Read-aloud book alignment";
        };

        host = host.name;
        # No dashboard-icons entry for this app - its own upstream logo instead.
        icon = "https://gitlab.com/storyteller-platform/storyteller/-/raw/main/applications/docs/static/img/Storyteller_Logo.png";
        label = "Storyteller";
        name = "storyteller";

        # Deliberately NOT `protected`: Storyteller does its own OIDC login against Authentik via
        # the `oidc` field below, so forward-auth on top would mean logging in twice (once at the
        # outpost, again at Storyteller's own login page) and would break its mobile/OPDS clients,
        # which have no browser session to carry an Authentik cookie.
        #
        # Storyteller is an Auth.js (NextAuth) app mounted at `/api/v2/auth` (`basePath` in
        # applications/web/src/auth/auth.ts), so its callback route is
        # `${AUTH_URL}/callback/${provider-id}`. For a CUSTOM provider that id is derived from the
        # provider's display name - lowercased, spaces to dashes, non-alphanumerics stripped
        # (`customProviderId`, same file) - so the name MUST be entered as "Authentik" in
        # Storyteller's settings for this registered URI to match.
        oidc = {
          client-secret = "storyteller-oidc-client-secret";
          redirect-paths = [ "/api/v2/auth/callback/authentik" ];
        };
      };
    };
}
