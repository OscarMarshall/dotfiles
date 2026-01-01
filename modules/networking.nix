{config, lib, ...}: {
  networking = {
    hostId = lib.mkIf (config.networking.hostName == "harmony") "7dab76c0";
    networkmanager.enable = lib.mkIf (config.networking.hostName == "melaan") true;
  };

  # Add users to networkmanager group on melaan
  users.users = lib.mkIf (config.networking.hostName == "melaan") {
    adelline.extraGroups = ["networkmanager"];
    oscar.extraGroups = ["networkmanager"];
  };
}
