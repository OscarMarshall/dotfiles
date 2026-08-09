{
  my.jellyfin =
    {
      global ? false,
    }:
    { host, ... }: {
      nixos.services.jellyfin = {
        enable = true;
        openFirewall = true;
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
