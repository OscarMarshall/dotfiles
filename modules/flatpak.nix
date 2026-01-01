{
  config,
  lib,
  ...
}: lib.mkIf (config.networking.hostName == "melaan") {
  services.flatpak.enable = true;
}
