{ oscarmarshall, ... }:
{
  den.aspects.OMARSHAL-M-2FD2 = {
    includes = with oscarmarshall; [
      fonts
      homebrew
      nix
    ];

    darwin = {
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
    };
  };
}
