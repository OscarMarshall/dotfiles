{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./hardware-configuration.nix
    ./cachix.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/users.nix
    ./modules/secrets.nix
    ./modules/nginx.nix
    ./modules/media-services.nix
    ./modules/minecraft.nix
    ./modules/vpn.nix
    ./modules/services.nix
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "/etc/nixos";
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs = {
    config = {
      allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "minecraft-server"
          "neoforge"
          "plexmediaserver"
        ];
    };
    overlays = [ inputs.nix-minecraft.overlay ];
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

  programs = {
    tmux.enable = true;
    zsh.enable = true;
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or
  # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}
