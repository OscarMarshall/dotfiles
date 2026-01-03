{pkgs, ...}: {
  fonts.packages = [
    pkgs.fira-code
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.symbols-only
  ];
}
