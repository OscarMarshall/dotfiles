{
  oscarmarshall.ci-no-boot = {
    includes = [ ];
    description = "Disables booting during CI";
    nixos = {
      boot.loader.grub.enable = false;
      fileSystems."/".device = "/dev/null";
    };
  };
}
