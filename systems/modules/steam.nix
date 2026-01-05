{
  lib,
  pkgs,
  ...
}: {
  # Use Homebrew cask on darwin, native package on NixOS
  config = lib.mkMerge [
    (lib.mkIf (!pkgs.stdenv.isDarwin) {
      programs.steam.enable = true;
    })
    (lib.mkIf pkgs.stdenv.isDarwin {
      homebrew.casks = ["steam"];
    })
  ];
}
