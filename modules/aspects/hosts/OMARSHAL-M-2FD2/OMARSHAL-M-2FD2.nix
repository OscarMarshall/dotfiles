{ my, ... }:
{
  den.aspects.OMARSHAL-M-2FD2 = {
    includes = with my; [ homebrew ];

    darwin = {
      age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAa8OO2Jgwvuz7J9LyceUlvlEk7GYkRJGnLaIzzYQCDQ";

      # Used for backwards compatibility, please read the changelog before changing.
      #
      # $ darwin-rebuild changelog
      system.stateVersion = 5;
    };

    provides.oscar = {
      homeManager = {
        # This value determines the Home Manager release that your configuration is compatible with. This helps avoid
        # breakage when a new Home Manager release introduces backwards incompatible changes.
        #
        # You can update Home Manager without changing this value. See the Home Manager release notes for a list of
        # state version changes in each release.
        home.stateVersion = "26.05";

        # On macOS, man is provided by the OS and programs.man.package is null,
        # so generateCaches has no effect; disable it to silence the warning.
        programs.man.generateCaches = false;
      };
    };
  };
}
