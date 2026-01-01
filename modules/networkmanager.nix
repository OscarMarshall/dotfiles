{
  config,
  lib,
  ...
}: lib.mkIf (config.networking.hostName == "melaan") {
  networking.networkmanager.enable = true;

  # Add users to networkmanager group
  users.users.adelline.extraGroups = ["networkmanager"];
  users.users.oscar.extraGroups = ["networkmanager"];
}
