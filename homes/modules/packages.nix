{pkgs, ...}: {
  home.packages = [
    pkgs.pinentry-tty
    pkgs.rcon-cli
  ];
}
