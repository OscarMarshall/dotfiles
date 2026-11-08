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
let
  # A preserved directory sitting directly under $HOME, i.e. the ones below. Two glib quirks to paper over:
  #
  #   - x-gvfs-hide: glib's "should this mount show in the file manager?" heuristic answers yes
  #     for anything mounted directly below $HOME, so every such bind mount would otherwise
  #     appear in Nautilus's sidebar as an ejectable drive. (The dotfile entries are already
  #     exempt - glib skips any mount path containing "/.".)
  #
  #   - x-gvfs-trash: glib's g_local_file_trash marks every mount whose /proc/self/mountinfo
  #     "root" field is not "/" as "system internal" (guess_system_internal, gio/gunixmounts.c)
  #     - which is every bind mount - and then refuses to trash files on it ("Trashing on
  #     system internal mounts is not supported"), so Nautilus only offers permanent delete.
  #     x-gvfs-trash is checked before that heuristic and forces trashing back on. glib then
  #     creates a per-directory ~/<dir>/.Trash-<uid>/ on first use (freedesktop spec behaviour
  #     for a non-$HOME filesystem); Nautilus's trash view aggregates them. Those live inside
  #     the persisted bind mount, so trashed files survive the per-boot /home wipe too, until
  #     the trash is emptied. See https://gitlab.gnome.org/GNOME/glib/-/issues/1271.
  #
  # Setting mountOptions replaces preservation's default [ "bind" "X-fstrim.notrim" ], so both
  # are respelled here.
  hiddenHomeBind = directory: {
    inherit directory;

    mountOptions = [
      "bind"
      "X-fstrim.notrim"
      "x-gvfs-hide"
      "x-gvfs-trash"
    ];
  };
in
{
  my.nautilus = {
    # The directories xdg.userDirs (below) points at, plus ~/Projects, survive the per-boot /home
    # wipe. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    #
    # `projects` (home-manager's XDG_PROJECTS_DIR) is left at its default ~/Projects and is the
    # git-checkout tree - preserved outright, not just snapshotted, so uncommitted work survives
    # even after rollback-home's pre-wipe snapshots are pruned (losing this tree to a reboot is what
    # prompted it), and this flake lives in it.
    includes = [
      ({ user, ... }: {
        preserve.users.${user.userName}.directories = map hiddenHomeBind [
          "Desktop"
          "Documents"
          "Downloads"
          "Music"
          "Pictures"
          "Projects"
          "Public"
          "Templates"
          "Videos"
        ];
      })
    ];

    # XDG user dirs (~/Downloads, ~/Documents, ~/Projects, ...). tensoon has no desktop
    # environment to run xdg-user-dirs-update, so without this ~/.config/user-dirs.dirs
    # never exists and Nautilus shows nothing under Home. home-manager rewrites the
    # file on every activation (it is not itself persisted); the directories it points
    # at are preserved above. createDirectories stays on as a fallback for the first boot
    # / a disabled-preservation config - mkdir -p over the existing bind mounts is a
    # no-op.
    homeManager.xdg.userDirs = {
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
