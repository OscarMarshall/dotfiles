{
  my.auto-upgrade = { allowReboot }: {
    nixos.system.autoUpgrade = {
      inherit allowReboot;
      enable = true;
      flake = "github:OscarMarshall/dotfiles";
    };
  };
}
