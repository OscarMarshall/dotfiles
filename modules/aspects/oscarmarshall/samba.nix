{ lib, ... }:
{
  oscarmarshall.samba = pool: shares: {
    nixos = {
      services = {
        samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global."map to guest" = "Bad User";
          }
          // (lib.genAttrs shares (share: {
            path = "${pool}/${share}";
            "guest ok" = "yes";
            "read only" = "yes";
            "write list" = "@users";
            browsable = "yes";
          }));
        };
        samba-wsdd = {
          enable = true;
          openFirewall = true;
        };
      };
    };
  };
}
