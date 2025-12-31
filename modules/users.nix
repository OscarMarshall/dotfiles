{pkgs, ...}: {
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      adelline = {
        description = "Adelline";
        isNormalUser = true;
        extraGroups = ["wheel"];
        hashedPassword = "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
      };
      oscar = {
        description = "Oscar Marshall";
        isNormalUser = true;
        extraGroups = ["wheel"];
        hashedPassword = "$y$j9T$rqKfWUlPbBLAGwIXUhAW61$LaP13MwCfvgtNlxZ/77.Pcu.tLapKf8CmepJ.GudcT4";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
        ];
        packages = [
          pkgs.rcon-cli
        ];
      };
    };
  };
}
