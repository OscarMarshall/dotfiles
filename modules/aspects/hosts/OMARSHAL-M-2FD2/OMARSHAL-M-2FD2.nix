{ my, ... }: {
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
      };

      # Den's allHomeNodes spawn re-walks the host aspect without the user's own includes, so none of the
      # hmXxx keys are present at compile time. Without them, the hmXxx→homeManager forwards compiled by
      # hmPlatforms become Tier 2 (complex) routes that call resolveSourceFallback, which creates a
      # self-parent inner spawn and throws. Sentinel empty modules here make each key present so the
      # forwards compile as Tier 1 (simple) routes instead.
      hmLinux = { };
      hmDarwin = { };
      hmAarch64 = { };
      hm64bit = { };
    };
  };
}
