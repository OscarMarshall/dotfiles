{pkgs, ...}: {
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      oscar = {
        description = "Oscar Marshall";
        isNormalUser = true;
        extraGroups = [
          "minecraft"
          "qbittorrent"
          "radarr"
          "sonarr"
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOn+wO9sZ8GoCRrg1BOkBK7/dPUojEdEaWoq2lHFYp9K omarshal"
        ];
        packages = [
          pkgs.rcon-cli
        ];
      };
      qbittorrent = {
        uid = 985;
        description = "qBittorrent service user";
        isSystemUser = true;
        group = "qbittorrent";
      };
      radarr.extraGroups = ["qbittorrent"];
      sonarr.extraGroups = ["qbittorrent"];
    };
    groups.qbittorrent.gid = 985;
  };

  programs = {
    tmux.enable = true;
    zsh.enable = true;
  };

  environment = {
    systemPackages = [
      pkgs.ddrescue
      pkgs.git
      pkgs.lm_sensors
      pkgs.rclone
      pkgs.wget
    ];
  };
}
