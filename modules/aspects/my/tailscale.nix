# Client side of my.headscale: joins this host to the self-hosted tailnet, so it's reachable from
# anywhere (no port-forward, unlike a plain WireGuard peer would need) with no manual "turn the VPN
# on" step - see headscale.nix's own header for the one-time server-side bootstrap this depends on.
#
# Joining is a one-time, human step per install: run `tailscale-join` (below) once, after which
# tailscaled persists its login in /var/lib/tailscale and reconnects on its own every boot. The
# preauth key lives in Proton Pass rather than agenix, so a reusable credential that can add any
# machine to the tailnet isn't sitting decrypted on every host's disk. That also rules out NixOS's
# `services.tailscale.authKeyFile`: pass-cli only works inside a logged-in session (its key is in
# gnome-keyring, see proton-pass.nix), never at boot as root.
#
# harmony runs the same `tailscale-join` - or the plain `tailscale up` it wraps - as part of
# headscale.nix's bootstrap, once headscale itself is up.
{
  my.tailscale = { loginServer }: {
    nixos = { config, pkgs, ... }: {
      environment.systemPackages = [
        # pass-cli runs as the invoking user (it needs their unlocked session) and only
        # `tailscale up` is elevated. The key goes through a 0600 temp file and
        # `--auth-key=file:` instead of argv, so it never shows up in `ps`. pass-cli isn't a
        # runtimeInput - it's unfree and comes from the user's own my.proton-pass profile.
        (pkgs.writeShellApplication {
          name = "tailscale-join";

          text = ''
            key=$(mktemp)
            trap 'rm -f "$key"' EXIT
            secret=$(pass-cli item view --vault-name Personal --item-title 'Headscale preauth key' --field Password --output human)
            printf '%s' "$secret" > "$key"
            sudo ${config.services.tailscale.package}/bin/tailscale up \
              --accept-dns \
              --auth-key="file:$key" \
              --login-server=${loginServer}
          '';
        })
      ];

      services.tailscale.enable = true;
    };

    # The node's identity (machine/node keys) and login live here. Without it an ephemeral-root
    # host (tensoon) would drop out of the tailnet on every boot and need `tailscale-join` again,
    # coming back as a brand-new node with a fresh tailnet IP and leaving a stale entry in
    # `headscale nodes list`. Inert on hosts without my.preservation (see preserve.nix).
    preserve.directories = [ "/var/lib/tailscale" ];
  };
}
