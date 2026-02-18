{
  my.ssh-server.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [ ghostty.terminfo ];

      programs.tmux.enable = true;

      services.openssh = {
        enable = true;
        openFirewall = true;
      };
    };
}
