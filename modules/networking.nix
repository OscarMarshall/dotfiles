{...}: {
  networking = {
    hostId = "7dab76c0";
    hostName = "harmony";
    networkmanager.enable = true;
    firewall = {
      allowedTCPPorts = [
        80
        443
        25565
      ];
      allowedUDPPorts = [51820];
    };
  };
}
