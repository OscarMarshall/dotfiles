{ ... }:

{
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
      allowedUDPPorts = [ 51820 ];
    };
  };

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
}
