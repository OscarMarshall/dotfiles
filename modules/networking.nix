{config, lib, ...}: {
  networking = {
    hostId = lib.mkIf (config.networking.hostName == "harmony") "7dab76c0";
    networkmanager.enable = true;
    firewall = lib.mkIf (config.networking.hostName == "harmony") {
      allowedTCPPorts = [
        80
        443
        25565
      ];
      allowedUDPPorts = [51820];
    };
  };
}
