{...}: {
  services = {
    apcupsd.enable = true;
    glances.enable = true;
    openssh = {
      enable = true;
      openFirewall = true;
    };
  };
}
