{ inputs, ... }:
let
  url = "auth.harmony.silverlight-nex.us";
in
{
  flake-file.inputs.authentik-nix = {
    url = "github:nix-community/authentik-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.authentik = {
    homepage-entry = {
      group = "Infra";
      label = "Authentik";
      description = "Single sign-on";
      href = "https://${url}";
    };

    secrets = { secrets, ... }: {
      authentik-secret-key = {
        generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 60";
        intermediary = true;
      };
      "authentik.env".generator = {
        dependencies = { inherit (secrets) authentik-secret-key; };
        script =
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            printf 'AUTHENTIK_SECRET_KEY=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.authentik-secret-key.file})"
          '';
      };
    };

    nixos = { config, ... }: {
      imports = [ (inputs.authentik-nix.nixosModules.default or { }) ];

      services.authentik = {
        enable = true;
        environmentFile = config.age.secrets."authentik.env".path;
        settings.disable_startup_analytics = true;
        nginx = {
          enable = true;
          enableACME = true;
          host = url;
        };
      };

      # nginx.nix forces `HttpOnly` onto every proxied cookie, but Authentik's frontend needs to
      # read its CSRF cookie via JavaScript (it echoes the value back as the X-Authentik-Csrf
      # header). With HttpOnly forced on, that read fails and Authentik rejects the empty token
      # with "CSRF token ... incorrect length". Reset the cookie rewrite for this vhost only.
      services.nginx.virtualHosts.${url}.extraConfig = ''
        proxy_cookie_path / /;
      '';
    };
  };
}
