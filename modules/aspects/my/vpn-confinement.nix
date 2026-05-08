{ ... }:
{
  flake-file.inputs.vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

  my."vpn-confinement" = {
    provides.service = serviceName: {
      nixos.systemd.services.${serviceName}.vpnConfinement = {
        enable = true;
        vpnNamespace = "proton0";
      };
    };
  };
}
