{
  my.profilarr =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 6868;
    in
    {
      dataset = {
        pool = "metalminds";
        name = "profilarr";
      };

      virtual-host = {
        name = "profilarr";
        host = host.name;
        protected = true;
        inherit port global;
        homepage = {
          group = "Arr Stack";
          label = "Profilarr";
          description = "Radarr/Sonarr custom format manager";
          icon = "profilarr.svg";
        };
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
