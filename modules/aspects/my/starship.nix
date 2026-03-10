{ inputs, ... }:
let
  rev = inputs.self.rev or null;
  dirtyRev = inputs.self.dirtyRev or null;
  actualRev =
    if rev != null then
      rev
    else if dirtyRev != null then
      builtins.replaceStrings [ "-dirty" ] [ "" ] dirtyRev
    else
      null;
  isDirty = rev == null && dirtyRev != null;
  flakeUrl = "github:OscarMarshall/dotfiles";
in
{
  my.starship = {
    homeManager = {
      programs.starship = {
        enable = true;
        presets = [ "nerd-font-symbols" ];
        settings.custom.nix-config-update = {
          command = "echo '${if isDirty then "!" else "↓"}'";
          symbol = "";
          style = "bold blue";
          # nix flake metadata results are cached by nix (default TTL: 3600s),
          # so this does not hit the network on every prompt render.
          when =
            if actualRev != null then
              ''latest=$(nix flake metadata ${flakeUrl} --json 2>/dev/null | jq -r '.revision // empty' 2>/dev/null); [ -n "$latest" ] && [ "$latest" != "${actualRev}" ]''
            else
              "false";
          description = "Shows when nix config revision is out of date";
        };
      };
    };
  };
}
