{config, ...}: {
  services.prowlarr.enable = true;
  services.flaresolverr.enable = true;

  services.nginx.virtualHosts."prowlarr.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:${toString config.services.prowlarr.settings.server.port}/";
  };
}
