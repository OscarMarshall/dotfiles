{
  my.jellyfin =
    {
      global ? false,
    }:
    { host, ... }: {
      nixos = { pkgs, ... }: {
        # UHD 770 (Raptor Lake iGPU, harmony's i9-13900K) - intel-media-driver (iHD) is Intel's
        # recommended VAAPI driver for Broadwell and newer.
        hardware.graphics = {
          enable = true;
          extraPackages = [ pkgs.intel-media-driver ];
        };

        services.jellyfin = {
          enable = true;

          hardwareAcceleration = {
            enable = true;
            device = "/dev/dri/renderD128";
            type = "vaapi";
          };

          openFirewall = true;
          transcoding.enableHardwareEncoding = true;
        };
      };

      port-forward = {
        name = "jellyfin";
        port = 8096;
      };

      virtual-host = {
        inherit global;
        group = "Media";
        homepage.description = "Media server";
        host = host.name;
        icon = "jellyfin.svg";
        label = "Jellyfin";
        name = "jellyfin";
        port = 8096;
      };
    };
}
