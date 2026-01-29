{config, ...}: {
  virtualisation.oci-containers.containers.profilarr = {
    image = "santiagosayshey/profilarr:v1.1.4@sha256:8a514f8429cd33885166facc9eb6504fa9ded056c737609e5e8ef32ae0afb350";
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
