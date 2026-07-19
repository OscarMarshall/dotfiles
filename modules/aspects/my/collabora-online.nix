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
      # Deliberately no homepage-entry: Collabora has no useful standalone landing page,
      # it's only used embedded inside Nextcloud.
      nixos.services.collabora-online = {
        inherit port;
        enable = true;
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
          # coolwsd.xml's own shipped comment on net.listen: "On systems where localhost resolves
          # to IPv6 [::1] address first, when net.proto is all and net.listen is loopback, coolwsd
          # unexpectedly listens on [::1] only. You need to change net.proto to IPv4, if you want
          # to use 127.0.0.1." Confirmed on harmony: journalctl showed "Bind to: IPv6 port: 9980"
          # and nothing on 127.0.0.1:9980, which nginx.nix's proxyPass targets for every
          # virtual-host - so every browser-facing request 502'd while Nextcloud's own WOPI
          # discovery (which is configured to hit http://[::1]:9980 directly) kept working.
          net.proto = "IPv4";
          server_name = url;
          ssl.enable = false; # nginx terminates TLS
          # Without this, coolwsd's own listener being plain HTTP makes it advertise http:// URLs
          # in its self-generated discovery.xml (urlsrc entries) - confirmed via
          # `curl http://127.0.0.1:9980/hosting/discovery`. richdocuments builds the browser-facing
          # editor iframe straight from that urlsrc, so the iframe embedded in Nextcloud's https
          # page pointed at http://collabora..., and the browser silently blocked it as mixed
          # active content (visible only in the console, never as a network request). ssl.termination
          # is coolwsd's own name for "tell clients this is https even though I only speak http" -
          # exactly this reverse-proxy-terminates-TLS setup.
          ssl.termination = true;
          # No explicit WOPI host allowlist: coolwsd.xml's storage.wopi.alias_groups defaults to
          # mode="first", which trusts whichever host connects first. That's fine since Nextcloud
          # is the only WOPI client here; there's no plain storage.wopi.host key in the real schema.
        };
      };
      virtual-host = {
        inherit port global;
        host = host.name;
        name = "collabora";
        websockets = true;
      };
    };
}
