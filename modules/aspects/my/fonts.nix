{
  my.fonts.os =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        fira-code
        nerd-fonts.fira-code
        nerd-fonts.symbols-only
      ];
    };
}
