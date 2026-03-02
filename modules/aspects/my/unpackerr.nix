{
  my.unpackerr.nixos =
    { config, ... }:
    {
      virtualisation.oci-containers.containers.unpackerr = {
        image = "golift/unpackerr:0.15.0@sha256:0fa5c63f8aeadc9b23a00b95d9e86bed185f1806b6291dc6b5a3e8974eca96e7";
        volumes = [ "/metalminds/torrents/downloads:/downloads" ];
        environment = {
          TZ = config.time.timeZone;
          UN_SONARR_0_URL = "https://sonarr.harmony.silverlight-nex.us";
          UN_RADARR_0_URL = "https://radarr.harmony.silverlight-nex.us";
        };
        environmentFiles = [ config.age.secrets."unpackerr.env".path ];
      };
    };
}
