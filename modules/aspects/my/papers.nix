# Papers (GNOME's GTK4 document viewer, Evince's successor) as the PDF viewer.
#
# Catppuccin comes for free, as with my.nautilus: Papers is GTK4/libadwaita and Noctalia's
# `gtk4` theme template (my.noctalia) already themes it.
#
# Installed system-wide so its thumbnailer (share/thumbnailers/papers.thumbnailer) lands in
# /run/current-system/sw, where the system-wide Nautilus finds it and renders PDF page previews.
{
  my.papers = {
    # No desktop environment picks a default PDF handler on tensoon, so set it explicitly -
    # otherwise opening a PDF from Nautilus or a browser download falls through to whatever
    # happens to claim application/pdf first.
    homeManager.xdg.mimeApps = {
      enable = true;
      defaultApplications."application/pdf" = "org.gnome.Papers.desktop";
    };

    nixos = { pkgs, ... }: { environment.systemPackages = [ pkgs.papers ]; };
  };
}
