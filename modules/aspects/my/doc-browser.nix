{
  my.doc-browser = { user, ... }: {
    darwin.homebrew.casks = [ "dash" ];
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.zeal ]; };

    # Zeal keeps every downloaded docset under ~/.local/share/Zeal (large; a fresh re-download
    # otherwise on each boot) and its settings under ~/.config/Zeal. `preserve`
    # (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [
      ".local/share/Zeal"
      ".config/Zeal"
    ];
  };
}
