{...}: {
  services.samba = {
    enable = true;
    settings = let
      commonShareAttrs = {
        "guest ok" = "yes";
        "read only" = "yes";
        "write list" = "@users";
        "browsable" = "yes";
      };
      shareList = [
        "backups"
        "documents"
        "minecraft-worlds"
        "movies"
        "music"
        "pictures"
        "shows"
        "torrents"
        "yarg-charts"
      ];
      generatedShares = builtins.listToAttrs (
        map (share: {
          name = share;
          value =
            commonShareAttrs
            // {
              path = "/metalminds/${share}";
            };
        })
        shareList
      );
    in
      {
        global = {
          "map to guest" = "Bad User";
        };
        processing = {
          path = "/metalminds/processing";
          "write list" = "@users";
          "browsable" = "yes";
        };
      }
      // generatedShares;
    openFirewall = true;
  };
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
