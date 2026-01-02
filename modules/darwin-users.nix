{
  config,
  lib,
  pkgs,
  ...
}: {
  # Only apply on darwin systems
  config = lib.mkIf pkgs.stdenv.isDarwin {
    users.users = lib.mkIf (config.networking.hostName == "omarshal-m-2fd2") {
      omarshal = {
        description = "Oscar Marshall";
        home = pkgs.lib.mkDefault /Users/omarshal;
        shell = pkgs.zsh;
      };
    };

    system.primaryUser = lib.mkIf (config.networking.hostName == "omarshal-m-2fd2") "omarshal";
  };
}
