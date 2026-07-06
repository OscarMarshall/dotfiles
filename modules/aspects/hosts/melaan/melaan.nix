{ inputs, my, ... }: {
  flake-file.inputs.nixos-hardware = {
    url = "github:NixOS/nixos-hardware";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.melaan = {
    includes = with my; [
      (auto-upgrade { allowReboot = false; })
      boot
      (cachyos-kernel { })
      gnome
      locale
      networkmanager
      pipewire
      steam
    ];

    nixos = {
      imports = [ (inputs.nixos-hardware.nixosModules.framework-12-13th-gen-intel or { }) ];

      age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqFHtkApjVtbJj4hR4sEyHJhwrZ74+gR3OviJk9VxYb";

      services = {
        flatpak.enable = true;
        openssh.enable = true;
        printing.enable = true;
      };

      # This option defines the first version of NixOS you have installed on this particular machine, and is used to
      # maintain compatibility with application data (e.g. databases) created on older NixOS versions.
      #
      # Most users should NEVER change this value after the initial install, for any reason, even if you've upgraded
      # your system to a new NixOS release.
      #
      # This value does NOT affect the Nixpkgs version your packages and OS are pulled from, so changing it will NOT
      # upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how to actually do that.
      #
      # This value being lower than the current NixOS release does NOT mean your system is out of date, out of support,
      # or vulnerable.
      #
      # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
      # and migrated your data accordingly.
      #
      # For more information, see `man configuration.nix` or
      # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
      system.stateVersion = "25.05"; # Did you read the comment?
    };

    # This value determines the Home Manager release that your configuration is compatible with. This helps avoid
    # breakage when a new Home Manager release introduces backwards incompatible changes.
    #
    # You can update Home Manager without changing this value. See the Home Manager release notes for a list of state
    # version changes in each release.
    provides =
      let
        # See the comment in Oscars-MacBook-Pro.nix for why these sentinels are needed.
        hmSentinels = {
          hmLinux = { };
          hmDarwin = { };
          hmAarch64 = { };
          hm64bit = { };
        };
      in
      {
        adelline = hmSentinels // {
          homeManager.home.stateVersion = "25.05";
        };
        oscar = hmSentinels // {
          homeManager.home.stateVersion = "25.05";
        };
      };
  };
}
