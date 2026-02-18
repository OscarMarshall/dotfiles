{ my, ... }:
{
  my.profilarr =
    let
      port = 6868;
    in
    {
      includes = with my; [ (nginx._.virtual-host "profilarr.harmony.silverlight-nex.us" port) ];

      nixos =
        { config, ... }:
        {
          virtualisation.oci-containers.containers.profilarr = {
            image = "santiagosayshey/profilarr:v1.1.4@sha256:8a514f8429cd33885166facc9eb6504fa9ded056c737609e5e8ef32ae0afb350";
            ports =
              let
                port' = toString port;
              in
              [ "127.0.0.1:${port'}:${port'}" ];
            volumes = [ "/metalminds/profilarr:/config" ];
            environment.TZ = config.time.timeZone;
          };
        };
    };
}
