{pkgs, ...}: {
  # Additional user configuration for melaan system
  users.users = {
    adelline = {
      extraGroups = ["networkmanager"];
      packages = with pkgs; [
        google-chrome
        ghostty
        krita
        rnote
      ];
    };
    oscar = {
      extraGroups = ["networkmanager"];
    };
  };
}
