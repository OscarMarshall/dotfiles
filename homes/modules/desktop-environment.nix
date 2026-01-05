{
  pkgs,
  lib,
  osConfig,
  ...
}: {
  # Packages for systems with a desktop environment
  home.packages = lib.optionals (
    osConfig.networking.hostName == "melaan" 
    || osConfig.networking.hostName == "omarshal-m-2fd2"
  ) [
    pkgs.discord
    pkgs.ghostty
    pkgs.inkscape
    pkgs.insomnia
    pkgs.logseq
    pkgs.prismlauncher
    pkgs.prusa-slicer
  ];
}
