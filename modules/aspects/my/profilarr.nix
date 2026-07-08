{
  my.profilarr =
    let
      url = "profilarr.harmony.silverlight-nex.us";
      port = 6868;
    in
    {
      virtual-host = {
        name = "profilarr";
        inherit url port;
      };

      homepage-entry = {
        group = "Arr Stack";
        label = "Profilarr";
        description = "Radarr/Sonarr custom format manager";
        href = "https://${url}";
      };

      nixos = { config, ... }: {
        virtualisation.oci-containers.containers.profilarr = {
          image = "santiagosayshey/profilarr:v1.1.5@sha256:8033e9c6d6995f37625afeb93d7020e99566f549ae83b65f1db7e11048952d0f";
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
