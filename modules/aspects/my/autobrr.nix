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
      secrets.autobrr-session-secret.generator.script = "alnum";
      # No `homepage` block: deliberately not a dashboard tile, but `icon`/`group` still feed its
      # Authentik application (see virtual-host.nix). No `label` either - "autobrr" IS the brand's
      # own styling.
      virtual-host = {
        inherit port global;
        group = "Arr Stack";
        host = host.name;
        icon = "https://raw.githubusercontent.com/autobrr/autobrr/develop/web/src/logo.svg";
        name = "autobrr";
        protected = true;
      };
    };
}
