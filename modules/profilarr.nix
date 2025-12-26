{config, ...}: {
  virtualisation.oci-containers.containers.profilarr = {
    image = "santiagosayshey/profilarr:latest";
    ports = ["127.0.0.1:6868:6868"];
    volumes = ["/metalminds/profilarr:/config"];
    environment.TZ = config.time.timeZone;
  };

  services.nginx.virtualHosts."profilarr.harmony.silverlight-nex.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:6868/";
  };
}
