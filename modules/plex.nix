{config, ...}: {
  services.plex = {
    enable = true;
    openFirewall = true;
  };

  services.nginx.virtualHosts."plex.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:32400/";
  };
}
