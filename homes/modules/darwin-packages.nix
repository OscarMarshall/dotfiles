{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}: {
  # Packages only for darwin systems
  home.packages =
    lib.optionals pkgs.stdenv.isDarwin [
      pkgs.bash
      pkgs.bash-language-server
      pkgs.eslint
      pkgs.fd
      pkgs.gnupg
      pkgs.mpv
      pkgs.nodePackages_latest.nodejs
      pkgs.pinentry_mac
      pkgs.ripgrep
      pkgs.rsync
      inputs.zen-browser.packages.aarch64-darwin.default
    ]
    ++ lib.optionals (pkgs.stdenv.isDarwin && osConfig.networking.hostName == "omarshal-m-2fd2") [
      pkgs.codex
    ];
}
