{ inputs, my, ... }: {
  flake-file.inputs.nixos-hardware = {
    url = "github:NixOS/nixos-hardware";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.tensoon = {
    includes = with my; [
      (auto-upgrade { allowReboot = false; })
      (cachyos-kernel { })
      boot
      disko
      locale
      networkmanager
      noctalia
      noctalia-greeter
      pipewire
      preservation
      ssh-server
      umbriel
    ];

    nixos = {
      imports = [ (inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series3 or { }) ];
      # Replace with tensoon's real /etc/ssh/ssh_host_ed25519_key.pub after the first install, then
      # run `agenix generate -a && agenix rekey -a` (YubiKey) and commit secrets/rekeyed/tensoon*.
      age.rekey.hostPubkey = "ssh-ed25519 AAAA_REPLACE_WITH_tensoon_ssh_host_ed25519_key_pub";

      services = {
        avahi = {
          enable = true;
          nssmdns4 = true;
        };

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
      #
      # Set during the initial install - confirm against `nixos-version` on the installer and match.
      system.stateVersion = "25.11";
    };

    # This value determines the Home Manager release that your configuration is compatible with. This helps avoid
    # breakage when a new Home Manager release introduces backwards incompatible changes.
    #
    # You can update Home Manager without changing this value. See the Home Manager release notes for a list of state
    # version changes in each release.
    provides =
      let
        # See the comment in OMARSHAL-M-T2QF.nix for why these sentinels are needed.
        hmSentinels = {
          hm64bit = { };
          hmAarch64 = { };
          hmDarwin = { };
          hmLinux = { };
        };
      in
      {
        oscar = hmSentinels // {
          homeManager.home.stateVersion = "25.11";
        };
      };
  };
}
