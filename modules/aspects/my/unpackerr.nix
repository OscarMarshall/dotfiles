{
  my.unpackerr.nixos =
    { config, ... }:
    {
      virtualisation.oci-containers.containers.unpackerr = {
        image = "golift/unpackerr:0.15.2@sha256:057e34740d26c34d81ec8e2faf8ec11f8dbfc77489b7a42826f52b37e5ee1b6c";
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
