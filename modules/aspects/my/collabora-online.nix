let
  url = "collabora.harmony.silverlight-nex.us";
  port = 9980;
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
        # No explicit WOPI host allowlist: coolwsd.xml's storage.wopi.alias_groups defaults to
        # mode="first", which trusts whichever host connects first. That's fine since Nextcloud
        # is the only WOPI client here; there's no plain storage.wopi.host key in the real schema.
      };
    };
  };
}
