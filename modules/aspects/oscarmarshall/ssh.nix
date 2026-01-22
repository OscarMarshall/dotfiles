{
  oscarmarshall.ssh.nixos = {
    programs.tmux.enable = true;

    services.openssh = {
      enable = true;
      openFirewall = true;
    };
  };
}
