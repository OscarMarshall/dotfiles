{config, ...}: {
  virtualisation.oci-containers.containers.profilarr = {
    image = "santiagosayshey/profilarr:v1.1.3@sha256:c8ad91a8e5d60b3816321b3a1f68332b29a23f910f6bd2c2d7b4a83f881f032f";
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
