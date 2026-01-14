{inputs, ...}: let
  username = "adelline";
in {
  flake.modules.nixos."${username}" = {pkgs, ...}: {
    home-manager.users."${username}" = {
      imports = [
        inputs.self.modules.homeManager."${username}"
      ];
    };

    users.users."${username}" = {
      description = "Adelline Marshall";
      isNormalUser = true;
      extraGroups = ["wheel"];
      hashedPassword = "$y$j9T$PIOU1O0/eDXQdlTWkzuf5.$AhnTDMJLgzM04nt6pzz/ae.3U.3LUWhte6PiBw.Mzb2";
    };
  };

  flake.modules.homeManager."${username}" = {
    config,
    pkgs,
    lib,
    osConfig,
    ...
  }: {
    home = {
      username = "${username}";
      stateVersion = "25.05";

      packages = lib.mkIf (osConfig.networking.hostName == "melaan") (
        with pkgs; [
          google-chrome
          ghostty
          krita
          prismlauncher
          rnote
        ]
      );
    };

    programs = {
      home-manager.enable = true;
    };
  };
}
