{
  flake.modules.nixos.networking = {
    config,
    lib,
    ...
  }: {
    networking = {
      hostId = lib.mkIf (config.networking.hostName == "harmony") "7dab76c0";
      networkmanager.enable = true;
    };

    users.users = {
      adelline.extraGroups = ["networkmanager"];
      oscar.extraGroups = ["networkmanager"];
    };
  };
}
