{
  my.prusa-slicer = { user, ... }: {
    homeManager = { pkgs, ... }: { home.packages = [ pkgs.prusa-slicer ]; };
    # Printer / filament / print-setting profiles and app config - see my.orca-slicer for the
    # rationale. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [ ".config/PrusaSlicer" ];
  };
}
