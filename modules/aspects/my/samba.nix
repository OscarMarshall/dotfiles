{
  my.samba = {
    nixos =
      { dataset, lib, ... }:
      let
        shares = builtins.filter (d: d.samba or false) dataset;
      in
      {
        services = {
          samba = {
            enable = true;
            openFirewall = true;
            settings = {
              global."map to guest" = "Bad User";
            }
            // (lib.listToAttrs (
              map (
                d:
                lib.nameValuePair d.name {
                  path = "/${d.pool}/${d.name}";
                  "guest ok" = if d.guestAccess or false then "yes" else "no";
                  "read only" = "yes";
                  "write list" = "@users";
                  browsable = "yes";
                }
              ) shares
            ));
          };
          samba-wsdd = {
            enable = true;
            openFirewall = true;
          };
        };
      };
  };
}
