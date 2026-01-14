{inputs, ...}: {
  flake.modules.nixos.harmony = {
    config,
    lib,
    ...
  }: {
    imports = with inputs.self.modules.nixos; [
      # System base
      boot
      networking
      nixpkgs
      system-core
      secrets

      # Infrastructure
      agenix
      home-manager
      nginx
      ssh
      zfs

      # Services
      apcupsd
      autobrr
      cross-seed
      glances
      gluetun
      homepage
      lm_sensors
      minecraft
      plex
      profilarr
      prowlarr
      qbittorrent
      radarr
      samba
      sonarr
      unpackerr

      # Users
      oscar
      adelline
    ];

    # Import nix-minecraft module
    imports = [
      inputs.nix-minecraft.nixosModules.minecraft-servers
    ];

    # Import hardware configuration
    imports = [../../systems/harmony/hardware-configuration.nix];

    # Import cachix configuration
    imports = [../../cachix.nix];

    # This option defines the first version of NixOS you have installed on this particular machine,
    # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
    system.stateVersion = "25.05"; # Did you read the comment?
  };
}
