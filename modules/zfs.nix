{...}: {
  boot = {
    supportedFilesystems = ["zfs"];
    zfs = {
      extraPools = ["metalminds"];
      forceImportRoot = false;
    };
  };

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    trim.enable = true;
  };
}
