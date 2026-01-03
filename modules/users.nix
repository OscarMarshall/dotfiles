{
  config,
  lib,
  pkgs,
  ...
}: {
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      adelline = {
        description = "Adelline";
        isNormalUser = lib.mkIf (!pkgs.stdenv.isDarwin) true;
        extraGroups = ["wheel"];
        hashedPassword = lib.mkIf (!pkgs.stdenv.isDarwin) "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
      };
      oscar = lib.mkMerge [
        {
          description = "Oscar Marshall";
          extraGroups = lib.mkIf (!pkgs.stdenv.isDarwin) ["wheel"];
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
          ];
          packages = [
            pkgs.rcon-cli
          ];
        }
        (lib.mkIf (!pkgs.stdenv.isDarwin) {
          isNormalUser = true;
          hashedPassword = "$y$j9T$rqKfWUlPbBLAGwIXUhAW61$LaP13MwCfvgtNlxZ/77.Pcu.tLapKf8CmepJ.GudcT4";
        })
        (lib.mkIf pkgs.stdenv.isDarwin {
          home = pkgs.lib.mkDefault /Users/omarshal;
          shell = pkgs.zsh;
        })
      ];
      # Create omarshal as an alias to oscar on darwin
      omarshal = lib.mkIf pkgs.stdenv.isDarwin config.users.users.oscar;
    };
  };

  # Set primary user for darwin
  system.primaryUser = lib.mkIf (pkgs.stdenv.isDarwin && config.networking.hostName == "omarshal-m-2fd2") "omarshal";
}
