{ inputs, ... }:
let
  isDirty = !(inputs.self ? rev);
  flakeUrl = "github:OscarMarshall/dotfiles";
  lastModified = toString inputs.self.lastModified;
in
{
  my.starship = {
    homeManager =
      { pkgs, ... }:
      {
        programs.starship = {
          enable = true;
          presets = [ "nerd-font-symbols" ];
          settings = {
            # Keep the default modules via $all, then append our custom indicators.
            format = "$all$custom.nix-config-dirty$custom.nix-config-update";
            custom = {
              nix-config-dirty = {
                command = "echo '!'";
                symbol = "";
                style = "bold blue";
                when = if isDirty then "true" else "false";
                description = "Shows when nix config is built from a dirty tree";
              };
              nix-config-update = {
                command = "echo '↓'";
                symbol = "";
                style = "bold blue";
                # nix flake metadata results are cached by nix (default TTL: 3600s),
                # so this does not hit the network on every prompt render.
                when =
                  if !isDirty then
                    ''latest_modified=$(${pkgs.nix}/bin/nix flake metadata ${flakeUrl} --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.lastModified // empty' 2>/dev/null); [ -n "$latest_modified" ] && [ "$latest_modified" -gt "${lastModified}" ]''
                  else
                    "false";
                description = "Shows when nix config is out of date";
              };
            };
          };
        };
      };
  };
}
