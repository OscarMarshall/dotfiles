{ inputs, ... }:
{
  flake-file.inputs.vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

  my."vpn-confinement" = {
    provides.service = serviceName: {
      nixos.systemd.services.${serviceName}.vpnConfinement = {
        enable = true;
        vpnNamespace = "proton0";
      };
    };

    provides.namespace =
      {
        webUiPort ? 8080,
        accessibleFrom ? [ "10.10.10.0/24" ],
        secretName,
        secretFile,
      }:
      {
        nixosSecrets.${secretName}.file = secretFile;

        nixos =
          { config, ... }:
          {
            imports = [ inputs.vpn-confinement.nixosModules.default ];

            vpnNamespaces.proton0 = {
              enable = true;
              wireguardConfigFile = config.age.secrets.${secretName}.path;
              inherit accessibleFrom;
              portMappings = [
                {
                  from = webUiPort;
                  to = webUiPort;
                }
              ];
            };
          };
      };
  };
}
