{
  config,
  lib,
  ...
}: {
  programs.tmux.enable = lib.mkIf (config.networking.hostName == "harmony") true;
}
