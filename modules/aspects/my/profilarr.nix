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
        name = "profilarr";
        pool = "metalminds";
      };

      nixos = { config, ... }: {
        virtualisation.oci-containers.containers.profilarr = {
          environment.TZ = config.time.timeZone;
          image = "santiagosayshey/profilarr:v1.1.5@sha256:8033e9c6d6995f37625afeb93d7020e99566f549ae83b65f1db7e11048952d0f";

          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];

          volumes = [ "/metalminds/profilarr:/config" ];
        };
      };

      virtual-host = {
        inherit global port;
        group = "Arr Stack";

        homepage = {
          description = "Radarr/Sonarr custom format manager";
        };

        host = host.name;
        icon = "https://raw.githubusercontent.com/Dictionarry-Hub/profilarr/develop/src/lib/client/assets/logo-512.png";
        label = "Profilarr";
        name = "profilarr";
        protected = true;
      };
    };
}
