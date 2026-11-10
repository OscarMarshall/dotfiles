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
      #
      # qui's own login stays enabled on top of Authentik's forward-auth, same as autobrr.nix -
      # `authDisabled` (plus the `I_ACKNOWLEDGE_THIS_IS_A_BAD_IDEA` it requires) is deliberately
      # left for a human to opt into, since anything that can reach the port then gets full
      # control of qui and every torrent client behind it.
      nixos = { config, ... }: {
        services.qui = {
          enable = true;
          secretFile = config.age.secrets.qui-session-secret.path;

          settings = {
            inherit port;
            host = "127.0.0.1";
          };
        };
      };

      # Read by systemd itself via the module's own `LoadCredential`, not by the `qui` user, so the
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
