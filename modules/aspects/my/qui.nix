{
  my.qui =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 7476;
    in
    {
      # qBittorrent instances themselves are added through qui's own UI (stored in its SQLite
      # database under /var/lib/qui, not its TOML config), so there's nothing to wire up from the
      # `torrent-client` quirk here - point it at qbittorrent.nix's `namespaceAddress`:8080
      # (192.168.15.1:8080), with no credentials needed: qui connects from the default namespace's
      # side of the veth/bridge pair, already inside qBittorrent's `AuthSubnetWhitelist`.
      nixos = { config, ... }: {
        services.qui = {
          enable = true;
          # Runs as qBittorrent's own user (qbittorrent.nix), same as the standalone cross-seed it
          # replaced: qui's reflink-mode cross-seed needs "Local filesystem access" to read
          # `/metalminds/torrents` and write its link trees there (`link-dir`). Running as the
          # dataset's owner leaves those trees owned exactly like everything else in it, so
          # qBittorrent can still write into them when a cross-seed downloads missing extras.
          group = "qbittorrent";
          secretFile = config.age.secrets.qui-session-secret.path;

          settings = {
            inherit port;
            I_ACKNOWLEDGE_THIS_IS_A_BAD_IDEA = true;
            # qui's own login is off, leaving Authentik's forward-auth (`protected` below) as the
            # only gate - same arrangement as qbittorrent.nix's `AuthSubnetWhitelist`. Anything that
            # reaches the port gets full control of qui and every torrent client behind it, so this
            # was an explicit opt-in.
            authDisabled = true;
            # qui checks this against the raw socket address, ahead of its own `RealIP` middleware
            # (internal/api/server.go), so nginx's forwarded headers can't widen it - loopback is
            # exactly nginx, given `host` below.
            authDisabledAllowedCIDRs = [ "127.0.0.1/32" ];
            host = "127.0.0.1";
          };

          user = "qbittorrent";
        };
      };

      # Read by systemd itself via the module's own `LoadCredential`, not by qui's user, so the
      # default root-only ownership is fine.
      secrets.qui-session-secret.generator.script = "hex";

      virtual-host = {
        inherit global port;
        group = "Arr Stack";
        homepage.description = "qBittorrent web UI";
        host = host.name;
        icon = "https://raw.githubusercontent.com/autobrr/qui/main/web/public/icon.png";
        name = "qui";
        protected = true;
      };
    };
}
