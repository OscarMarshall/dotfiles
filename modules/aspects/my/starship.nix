{ self, ... }:
let
  isDirty = !(self ? rev);
in
{
  my.starship = {
    homeManager =
      { pkgs, ... }:
      {
        programs.starship = {
          enable = true;
          presets = [ "nerd-font-symbols" ];
          settings.custom.nix-config = {
            description = "Shows the current nix config status";
            shell = [ "${pkgs.bash}/bin/bash" ];
            style = "bold blue";
            symbol = "";
            ignore_timeout = true;
          }
          // (
            if isDirty then
              {
                command = "echo '!'";
                when = true;
              }
            else
              {
                # Compare our pinned revision against main on GitHub to determine
                # whether we are behind, diverged, or up-to-date.  Results are
                # cached in ~/.cache/starship/ with a 60-minute TTL so that we
                # do not hit the GitHub API on every prompt render.
                command = ''
                  cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/starship"
                  cache_file="$cache_dir/nix-config-${self.rev}"

                  if [ -f "$cache_file" ] && [ -z "$(find "$cache_file" -mmin +60 2>/dev/null)" ]; then
                    status=$(cat "$cache_file")
                  else
                    status=$(
                      ${pkgs.curl}/bin/curl -sf \
                        "https://api.github.com/repos/OscarMarshall/dotfiles/compare/${self.rev}...main" |
                        ${pkgs.jq}/bin/jq -r '.status // empty' 2>/dev/null
                    )
                    if [ -n "$status" ]; then
                      mkdir -p "$cache_dir"
                      printf '%s' "$status" > "$cache_file"
                    fi
                  fi

                  case "$status" in
                    # main is ahead of our revision: newer commits are available.
                    ahead) echo '⇣' ;;
                    # our revision is not reachable from main.
                    behind | diverged) echo $'\ue725' ;;
                  esac
                '';
                when = true;
              }
          );
        };
      };
  };
}
