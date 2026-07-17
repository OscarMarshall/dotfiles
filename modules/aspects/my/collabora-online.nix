let
  domain = "silverlight-nex.us";
  port = 9980;
in
{
  my.collabora-online =
    {
      global ? false,
    }:
    { host, ... }:
    let
      url = "collabora.${host.name}.${domain}";
    in
    {
      virtual-host = {
        name = "collabora";
        host = host.name;
        inherit port global;
        websockets = true;
      };

      # Deliberately no homepage-entry: Collabora has no useful standalone landing page,
      # it's only used embedded inside Nextcloud.

      nixos.services.collabora-online = {
        enable = true;
        inherit port;
        settings = {
          # These MUST be nested attrsets, not quoted dotted keys: this option's freeform type maps
          # attribute NESTING onto XML nesting, so `"ssl.enable"` is one attribute whose name merely
          # contains a dot. It lands beside the real `ssl` set rather than inside it, emitting a
          # junk `<ssl.enable>` element that coolwsd ignores while `<ssl><enable>` keeps whatever it
          # would have been - which is on, since the module only ever sets `ssl.{ca,cert,key}` (the
          # dummy self-signed certs it ships for testing) and never `ssl.enable`. Nothing warns
          # about the stray key; the failure surfaces at the far end as Nextcloud's plain-HTTP WOPI
          # probe getting "cURL error 52: Empty reply from server" off a TLS listener.
          net.listen = "loopback";
          ssl.enable = false; # nginx terminates TLS
          server_name = url;
          # No explicit WOPI host allowlist: coolwsd.xml's storage.wopi.alias_groups defaults to
          # mode="first", which trusts whichever host connects first. That's fine since Nextcloud
          # is the only WOPI client here; there's no plain storage.wopi.host key in the real schema.
        };
      };
    };
}
