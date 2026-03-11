{ self, ... }:
let
  isDirty = !(self ? rev);
  # Extract the base commit SHA: self.rev when clean, or strip the "-dirty" suffix
  # from self.dirtyRev (available in Nix >= 2.11) when dirty.
  rev =
    if self ? rev then self.rev
    else if self ? dirtyRev then builtins.substring 0 40 self.dirtyRev
    else null;
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
            when = true;
            # Accumulate all applicable indicators into $symbols.
            # Both the dirty marker and the branch-status marker may appear
            # at the same time (e.g. uncommitted changes on a non-main rev).
            command =
              let
                dirtyPart = if isDirty then ''symbols="!"'' else "";
                apiPart =
                  if rev != null then
                    ''
                      # Compare our pinned revision against main on GitHub to determine
                      # whether we are behind, diverged, or up-to-date.  Results are
                      # cached in ~/.cache/starship/ with a 60-minute TTL so that we
                      # do not hit the GitHub API on every prompt render.
                      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/starship"
                      cache_file="$cache_dir/nix-config-${rev}"

                      if [ -f "$cache_file" ] && [ -z "$(find "$cache_file" -mmin +60 2>/dev/null)" ]; then
                        status=$(cat "$cache_file")
                      else
                        status=$(
                          ${pkgs.curl}/bin/curl -sf \
                            "https://api.github.com/repos/OscarMarshall/dotfiles/compare/${rev}...main" |
                            ${pkgs.jq}/bin/jq -r '.status // empty' 2>/dev/null
                        )
                        if [ -n "$status" ]; then
                          mkdir -p "$cache_dir"
                          printf '%s' "$status" > "$cache_file"
                        fi
                      fi

                      case "$status" in
                        # main is ahead of our revision: newer commits are available.
                        ahead) symbols="''${symbols}⇣" ;;
                        # our revision is not reachable from main.
                        behind | diverged) symbols="''${symbols}$'\ue725'" ;;
                      esac
                    ''
                  else
                    "";
              in
              ''
                symbols=""
                ${dirtyPart}
                ${apiPart}
                echo "$symbols"
              '';
          };
        };
      };
  };
}
