{
  my.ssh-server = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [ ghostty.terminfo ];
      programs.tmux.enable = true;

      services.openssh = {
        enable = true;
        openFirewall = true;
      };
    };

    # The host keys - also the host's agenix identity (my.preservation points age.identityPaths at
    # their /persist copies for the initrd decrypt). Symlinked, not bind-mounted, with
    # configureParent so /etc/ssh exists on the tmpfs root. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.files =
      map
        (file: {
          inherit file;
          configureParent = true;
          how = "symlink";
        })
        [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
  };
}
