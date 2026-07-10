let
  url = "collabora.harmony.silverlight-nex.us";
  port = 9980;
  nextcloudUrl = "nextcloud.harmony.silverlight-nex.us"; # keep in sync with nextcloud.nix
in
{
  my.collabora-online = {
    virtual-host = {
      name = "collabora";
      inherit url port;
      websockets = true;
    };

    # Deliberately no homepage-entry: Collabora has no useful standalone landing page,
    # it's only used embedded inside Nextcloud.

    nixos.services.collabora-online = {
      enable = true;
      inherit port;
      settings = {
        "net.listen" = "loopback";
        "ssl.enable" = false; # nginx terminates TLS
        server_name = url;
        storage.wopi.host = [ "https://${nextcloudUrl}" ];
      };
    };
  };
}
