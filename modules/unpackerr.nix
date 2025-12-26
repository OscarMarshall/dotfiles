{config, ...}: {
  virtualisation.oci-containers.containers.unpackerr = {
    image = "golift/unpackerr";
    volumes = ["/metalminds/torrents/downloads:/downloads"];
    environment = {
      TZ = config.time.timeZone;
      UN_SONARR_0_URL = "https://sonarr.harmony.silverlight-nex.us";
      UN_RADARR_0_URL = "https://radarr.harmony.silverlight-nex.us";
    };
    environmentFiles = [config.age.secrets."unpackerr.env".path];
  };
}
