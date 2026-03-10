{ self, ... }:
let
  inherit (self) lastModified;
  isDirty = !(self ? rev);
  flakeUrl = "github:OscarMarshall/dotfiles";
in
{
  my.starship = {
    homeManager =
      { pkgs, ... }:
      {
        programs.starship = {
          enable = true;
          presets = [ "nerd-font-symbols" ];
          settings.custom.nix-config =
            if isDirty then
              {
                description = "Shows when nix config is built from a dirty tree";
                command = "echo '!'";
                symbol = "";
                style = "bold blue";
                when = "true";
              }
            else
              {
                description = "Shows when nix config is out of date";
                command = "echo '↓'";
                symbol = "";
                style = "bold blue";
                shell = [ "bash" ];
                # nix flake metadata results are cached by nix (default TTL: 3600s),
                # so this does not hit the network on every prompt render.
                when = ''
                  latest_modified=$(
                    ${pkgs.nix}/bin/nix flake metadata ${flakeUrl} --json 2>/dev/null |
                      ${pkgs.jq}/bin/jq -r '.lastModified // empty' 2>/dev/null
                  );

                  [ -n "$latest_modified" ] && [ "$latest_modified" -gt "${toString lastModified}" ]
                '';
              };
        };
      };
  };
}
