{
  flake.modules.nixos.prowlarr = {config, ...}: {
    services = {
      prowlarr.enable = true;
      flaresolverr.enable = true;

      nginx.virtualHosts."prowlarr.harmony.silverlight-nex.us" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://127.0.0.1:${toString config.services.prowlarr.settings.server.port}/";
      };
    };
  };
}
