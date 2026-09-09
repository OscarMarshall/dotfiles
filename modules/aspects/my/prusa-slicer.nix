# NOTE: I'd prefer to use pkgs.prusa-slicer for darwin, but it's currently broken.

{
  my.prusa-slicer = { user, ... }: {
    darwin.homebrew.casks = [ "prusaslicer" ];
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.prusa-slicer ]; };
    # Printer / filament / print-setting profiles and app config - see my.orca-slicer for the
    # rationale. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [ ".config/PrusaSlicer" ];
  };
}
