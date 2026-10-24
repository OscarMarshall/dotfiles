# Client side of my.headscale: joins this host to the self-hosted tailnet, so it's reachable from
# anywhere (no port-forward, unlike a plain WireGuard peer would need) with no manual "turn the VPN
# on" step - see headscale.nix's own header for the one-time server-side bootstrap this depends on.
#
# `unattended = true` wires up fully hands-off join via a shared, long-lived, reusable preauth key
# (the `tailscale-authkey` secret, minted by headscale.nix's bootstrap): NixOS's
# `services.tailscale.authKeyFile`/`extraUpFlags` bring the interface up and re-authenticate on
# every boot with zero interaction. nix-darwin's tailscale module has no such option - it only
# turns on the daemon - so OMARSHAL-M-T2QF still needs ONE manual, one-time
#   sudo tailscale up --login-server=<loginServer> --accept-dns --authkey="$(cat /run/agenix/tailscale-authkey)"
# after which tailscaled persists its login and reconnects on its own like every other host, same
# as the NixOS side.
#
# harmony (headscale.nix) includes this WITHOUT `unattended` - it can't consume a preauth key that
# only exists once headscale, which harmony itself hosts, is already up and running. It joins via
# that same one-time manual command instead, as part of headscale.nix's bootstrap sequence.
{ lib, ... }: {
  my.tailscale =
    {
      loginServer,
      unattended ? false,
    }:
    {
      nixos =
        { config, ... }:
        lib.optionalAttrs unattended {
          services.tailscale = {
            authKeyFile = config.age.secrets.tailscale-authkey.path;

            extraUpFlags = [
              "--accept-dns"
              "--login-server=${loginServer}"
            ];
          };
        };

      os.services.tailscale.enable = true;
    }
    // lib.optionalAttrs unattended { secrets.tailscale-authkey.rekeyFile = ../../../secrets/tailscale-authkey.age; };
}
