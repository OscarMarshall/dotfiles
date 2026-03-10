{ inputs, ... }:
let
  rev = inputs.self.rev or null;
  flakeUrl = "github:OscarMarshall/dotfiles";
in
{
  my.starship = {
    homeManager = {
      programs.starship = {
        enable = true;
        settings.custom.nix-config-update = {
          command = "echo 'out of date'";
          symbol = " ";
          style = "bold blue";
          # nix flake metadata results are cached by nix (default TTL: 3600s),
          # so this does not hit the network on every prompt render.
          when =
            if rev != null then
              ''latest=$(nix flake metadata ${flakeUrl} --json 2>/dev/null | jq -r '.revision // empty' 2>/dev/null); [ -n "$latest" ] && [ "$latest" != "${rev}" ]''
            else
              "false";
          description = "Shows when nix config revision is out of date";
        };
      };
    };
  };
}
