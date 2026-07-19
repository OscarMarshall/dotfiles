{
  my.pipewire.nixos = {
    security.rtkit.enable = true;
    services.pipewire = {
      alsa = {
        enable = true;
        support32Bit = true;
      };
      enable = true;
      pulse.enable = true;
    };
  };
}
