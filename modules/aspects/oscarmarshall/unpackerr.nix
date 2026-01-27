{
  oscarmarshall.unpackerr = {
    includes = [ ];
    nixos =
      { config, ... }:
      {
        virtualisation.oci-containers.containers.unpackerr = {
          image = "golift/unpackerr:0.14.5@sha256:8493ffc2dd17e0b8a034552bb52d44e003fa457ee407da97ccc69328bce4a815";
          volumes = [ "/metalminds/torrents/downloads:/downloads" ];
          environment = {
            TZ = config.time.timeZone;
            UN_SONARR_0_URL = "https://sonarr.harmony.silverlight-nex.us";
            UN_RADARR_0_URL = "https://radarr.harmony.silverlight-nex.us";
          };
          environmentFiles = [ config.age.secrets."unpackerr.env".path ];
        };
      };
  };
}
