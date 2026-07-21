{
  my.samba.nixos =
    { lib, dataset, ... }:
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
                browsable = "yes";
                "guest ok" = if d.guestAccess or false then "yes" else "no";
                path = "/${d.pool}/${d.name}";
                "read only" = "yes";
                "write list" = "@users";
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
}
