# Client side of my.headscale: joins this host to the self-hosted tailnet, so it's reachable from
# anywhere (no port-forward, unlike a plain WireGuard peer would need) with no manual "turn the VPN
# on" step - see headscale.nix's own header for the one-time server-side bootstrap this depends on.
#
# `unattended = true` wires up fully hands-off join via a shared, long-lived, reusable preauth key
# (the `tailscale-authkey` secret, minted by headscale.nix's bootstrap):
# `services.tailscale.authKeyFile`/`extraUpFlags` bring the interface up and re-authenticate on
# every boot with zero interaction.
#
# harmony (headscale.nix) includes this WITHOUT `unattended` - it can't consume a preauth key that
# only exists once headscale, which harmony itself hosts, is already up and running. It joins via a
# one-time manual `tailscale up` instead, as part of headscale.nix's bootstrap sequence, after which
# tailscaled persists its login and reconnects on its own like every other host.
{ lib, ... }: {
  my.tailscale =
    {
      loginServer,
      unattended ? false,
    }:
    {
      nixos = { config, ... }: {
        services.tailscale = {
          enable = true;
        }
        // lib.optionalAttrs unattended {
          authKeyFile = config.age.secrets.tailscale-authkey.path;

          extraUpFlags = [
            "--accept-dns"
            "--login-server=${loginServer}"
          ];
        };
      };

      # The node's identity (machine/node keys) and login live here. Without it an ephemeral-root
      # host (tensoon) would re-register as a brand-new node from the preauth key on every boot,
      # piling up stale entries in `headscale nodes list` and getting a fresh tailnet IP each time.
      # Inert on hosts without my.preservation (see preserve.nix).
      preserve.directories = [ "/var/lib/tailscale" ];
    }
    // lib.optionalAttrs unattended { secrets.tailscale-authkey.rekeyFile = ../../../secrets/tailscale-authkey.age; };
}
