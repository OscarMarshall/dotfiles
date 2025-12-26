{config, ...}: {
  services.sonarr.enable = true;

  services.nginx.virtualHosts."sonarr.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:${toString config.services.sonarr.settings.server.port}/";
  };
}
