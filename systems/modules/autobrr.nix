{config, ...}: {
  services.autobrr = {
    enable = true;
    secretFile = config.age.secrets.autobrr-secret.path;
    settings = {
      checkForUpdates = true;
      host = "127.0.0.1";
      port = 7474;
    };
  };

  services.nginx.virtualHosts."autobrr.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:${toString config.services.autobrr.settings.port}/";
  };
}
