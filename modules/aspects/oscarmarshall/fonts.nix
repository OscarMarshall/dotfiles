let
  fonts =
    pkgs:
    (with pkgs; [
      fira-code
      nerd-fonts.fira-code
      nerd-fonts.symbols-only
    ]);
in
{
  oscarmarshall.fonts = {
    darwin =
      { pkgs, ... }:
      {
        fonts.packages = fonts pkgs;
      };

    nixos =
      { pkgs, ... }:
      {
        fonts.packages = fonts pkgs;
      };
  };
}
