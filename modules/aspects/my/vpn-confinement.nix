{ inputs, ... }:
let
  port = 8080;
  accessibleFromSubnet = "10.10.10.0/24";
in
{
  flake-file.inputs.vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

  my."vpn-confinement" = {
    provides.service = serviceName: {
      nixos.systemd.services.${serviceName}.vpnConfinement = {
        enable = true;
        vpnNamespace = "proton0";
      };
    };

    nixosSecrets."Harmony_P2P-US-CA-898.conf".file = ../../../secrets/Harmony_P2P-US-CA-898.conf.age;

    nixos =
      { config, ... }:
      {
        imports = [ inputs.vpn-confinement.nixosModules.default ];

        vpnNamespaces.proton0 = {
          enable = true;
          wireguardConfigFile = config.age.secrets."Harmony_P2P-US-CA-898.conf".path;
          accessibleFrom = [ accessibleFromSubnet ];
          portMappings = [
            {
              from = port;
              to = port;
            }
          ];
        };
      };
  };
}
