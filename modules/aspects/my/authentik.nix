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
    };
  };
}
