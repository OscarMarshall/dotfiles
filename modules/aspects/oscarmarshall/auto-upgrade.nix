{
  oscarmarshall.auto-upgrade =
    { allowReboot }:
    {
      includes = [ ];
      nixos = {
        system.autoUpgrade = {
          enable = true;
          inherit allowReboot;
          flake = "github:OscarMarshall/dotfiles";
        };
      };
    };
}
