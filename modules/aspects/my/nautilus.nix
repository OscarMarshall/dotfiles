# Nautilus (GNOME Files) as the GUI file manager. tensoon runs no DE, so the pieces
# gnome-shell would normally pull in around it have to be named explicitly:
#
#   - gvfs: trash, MTP/PTP, and network/removable mounts. Nautilus's trash and its
#     "browse this USB stick" flow both silently no-op without it.
#   - sushi: the Space-bar quick previewer.
#   - nautilus-open-any-terminal: adds an "Open in Terminal" context entry (a bare
#     Umbriel session has no shell-provided one), pointed at ghostty - this host's
#     terminal (my.ghostty). The module writes the gsettings default via the dconf
#     user profile, which my.noctalia's NixOS block already enables.
#   - file-roller: the archive extract/compress context menu Nautilus delegates to.
#   - adwaita-icon-theme / hicolor-icon-theme: the icon set Nautilus's places
#     ("Starred", "Recent", trash, ...) and toolbar draw from. gnome-shell would
#     provide it; here nothing else does, so a bare session renders those broken.
#
# Catppuccin comes for free: Nautilus is GTK4 and Noctalia's `gtk4` theme template
# (my.noctalia) already themes it. Noctalia's template sets `color-scheme` and
# `gtk-theme` but never `icon-theme`, so Adwaita (the schema default) stays in use.
#
# Nautilus itself is installed system-wide rather than via home.packages so the
# nautilus-python extension above is discovered by the same Nautilus, and so the
# sushi/gvfs D-Bus services activate against it.
{
  my.nautilus = {
    # XDG user dirs (~/Downloads, ~/Documents, ~/Projects, ...). tensoon has no desktop
    # environment to run xdg-user-dirs-update, so without this ~/.config/user-dirs.dirs
    # never exists and Nautilus shows nothing under Home. home-manager rewrites the
    # file on every activation (it is not itself persisted); the directories it points
    # at are persisted and bind-mounted by my.preservation, which survives the
    # per-boot /home wipe. createDirectories stays on as a fallback for the first boot
    # / a disabled-preservation config - mkdir -p over the existing bind mounts is a
    # no-op.
    #
    # `projects` (home-manager's XDG_PROJECTS_DIR) is left at its default ~/Projects and
    # is the git-checkout tree - my.preservation keeps it outright, and this flake lives
    # in it. It is not one of the freedesktop-standard dirs, so my.preservation lists it
    # explicitly rather than in its XDG-dir loop.
    hmLinux.xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };

    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        adwaita-icon-theme
        file-roller
        hicolor-icon-theme
        nautilus
      ];

      programs.nautilus-open-any-terminal = {
        enable = true;
        terminal = "ghostty";
      };

      services = {
        gnome.sushi.enable = true;
        gvfs.enable = true;
      };
    };
  };
}
