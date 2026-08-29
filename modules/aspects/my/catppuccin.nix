# Catppuccin Mocha pointer cursor for the graphical session. Everything else Catppuccin
# (shell colours, GTK/Qt) is now Noctalia's job via its theme templates - this aspect only
# survives to pin the cursor, which Noctalia does not manage.
#
# my.noctalia-greeter references the same catppuccin-cursors.mochaDark package directly.
{
  # hmLinux: home.pointerCursor is Linux-only, and macOS manages the cursor itself.
  my.catppuccin.hmLinux = { pkgs, ... }: {
    home.pointerCursor = {
      enable = true;
      package = pkgs.catppuccin-cursors.mochaDark;
      gtk.enable = true;
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
      x11.enable = true;
    };
  };
}
