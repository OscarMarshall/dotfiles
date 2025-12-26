{...}: {
  services = {
    apcupsd.enable = true;
    glances.enable = true;
    openssh = {
      enable = true;
      openFirewall = true;
    };
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
      trim.enable = true;
    };
  };
}
