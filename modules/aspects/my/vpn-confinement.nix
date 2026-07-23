# The `vpn-confinement` quirk: any aspect contributes one (or a list) alongside its `nixos` config
# to request that one of its own systemd services be confined to the `proton0` VPN namespace this
# aspect manages. Lives in its own file for the same reason virtual-host.nix/port-forward.nix do -
# it no longer belongs to any single consumer.
#
# Record shape: the plain systemd service name (a string), or a list of them - never a function.
# Den auto-flattens list-valued quirk contributions, so an aspect confining more than one service
# (e.g. qBittorrent's own service plus its port-forward sidecar) just returns a list.
{ inputs, ... }: {
  flake-file.inputs.vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
  den.quirks.vpn-confinement.description = "Systemd services confined to the `proton0` VPN namespace";

  my.vpn-confinement.nixos = { lib, vpn-confinement, ... }: {
    imports = [ inputs.vpn-confinement.nixosModules.default ];

    # `vpn-confinement` is documented as a string or a list of them; genAttrs needs a list, so
    # normalize a lone string (a single-service contribution) before calling it.
    systemd.services = lib.genAttrs (lib.toList vpn-confinement) (_: {
      vpnConfinement = {
        enable = true;
        vpnNamespace = "proton0";
      };
    });
  };
}
