{
  my.autobrr =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 7474;
    in
    {
      # No `homepage` block: deliberately not a dashboard tile, but `icon` still feeds its Authentik
      # application (see virtual-host.nix). No `label` either - "autobrr" IS the brand's own styling.
      virtual-host = {
        name = "autobrr";
        host = host.name;
        protected = true;
        icon = "https://raw.githubusercontent.com/autobrr/autobrr/develop/web/src/logo.svg";
        inherit port global;
      };

      secrets.autobrr-session-secret.generator.script = "alnum";

      nixos = { config, ... }: {
        services.autobrr = {
          enable = true;
          secretFile = config.age.secrets.autobrr-session-secret.path;
          settings = {
            inherit port;
            checkForUpdates = true;
            host = "127.0.0.1";
          };
        };
      };
    };
}
