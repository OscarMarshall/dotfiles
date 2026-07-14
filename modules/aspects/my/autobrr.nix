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
      virtual-host = {
        name = "autobrr";
        host = host.name;
        protected = true;
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
