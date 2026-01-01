{
  config,
  lib,
  ...
}: lib.mkIf (config.networking.hostName == "melaan") {
  services.printing.enable = true;
}
