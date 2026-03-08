{
  my.unpackerr.nixos =
    { config, ... }:
    {
      virtualisation.oci-containers.containers.unpackerr = {
        image = "golift/unpackerr:0.15.1@sha256:0cf85db2763f776bdbbdae68826262f7464c641dd542bc8bded8c64de5539dae";
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
