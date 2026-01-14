{inputs, ...}: let
  username = "adelline";
in {
  flake.modules.nixos."${username}" = {pkgs, ...}: {
    home-manager.users."${username}" = {
      imports = [
        inputs.self.modules.homeManager."${username}"
      ];
    };

    users = {
      defaultUserShell = pkgs.zsh;
      users."${username}" = {
        description = "Adelline";
        isNormalUser = true;
        extraGroups = ["wheel"];
        hashedPassword = "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
      };
    };
  };

  flake.modules.homeManager."${username}" = _: {
    home = {
      username = "${username}";
      stateVersion = "25.05";
    };

    programs = {
      git = {
        enable = true;
        settings.user = {
          name = "Adelline Huang";
          email = "adelline.huang@gmail.com";
        };
      };
      home-manager.enable = true;
    };
  };
}
