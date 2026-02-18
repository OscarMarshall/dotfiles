{
  my.auto-upgrade =
    { allowReboot }:
    {
      nixos = {
        system.autoUpgrade = {
          enable = true;
          inherit allowReboot;
          flake = "github:OscarMarshall/dotfiles";
        };
      };
    };
}
