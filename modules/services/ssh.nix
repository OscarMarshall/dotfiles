{
  flake.modules.nixos.ssh = _: {
    programs.tmux.enable = true;

    services.openssh = {
      enable = true;
      openFirewall = true;
    };
  };
}
