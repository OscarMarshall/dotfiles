{
  my.orca-slicer = { user, ... }: {
    darwin.homebrew.casks = [ "orcaslicer" ];
    hmLinux = { pkgs, ... }: { home.packages = [ pkgs.orca-slicer ]; };
    # Printer / filament / process profiles, app config and login all live here - lost on every
    # boot on an ephemeral-root host without this. `preserve` (modules/aspects/my/preserve.nix) is
    # inert wherever my.preservation isn't included.
    preserve.users.${user.userName}.directories = [ ".config/OrcaSlicer" ];
  };
}
