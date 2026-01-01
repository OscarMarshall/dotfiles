{
  config,
  lib,
  ...
}: lib.mkIf (config.networking.hostName == "melaan") {
  programs.steam.enable = true;
}
