{config, ...}: {
  services.radarr.enable = true;

  services.nginx.virtualHosts."radarr.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:${toString config.services.radarr.settings.server.port}/";
  };
}
