{inputs, ...}: {
  imports =
    (with inputs.self.modules.nixos; [
      # System base
      boot
      networking
      nixpkgs
      system-core

      # Infrastructure
      home-manager

      # Desktop environment
      flatpak
      gnome
      pipewire
      printing
      steam

      # Users
      oscar
      adelline
    ])
    ++ [
      # External modules
      inputs.nixos-hardware.nixosModules.framework-12-13th-gen-intel
      ./hardware-configuration.nix
      ../../cachix.nix
    ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.05"; # Did you read the comment?
}
