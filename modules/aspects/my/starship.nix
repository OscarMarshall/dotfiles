{ lib, self, ... }:
let
  isDirty = self ? dirtyRev;
  # Extract the base commit SHA: self.rev when clean, or strip the "-dirty" suffix
  # from self.dirtyRev (available in Nix >= 2.11) when dirty.
  rev =
    if self ? rev then
      self.rev
    else if self ? dirtyRev then
      builtins.substring 0 40 self.dirtyRev
    else
      null;
in
{
  my.starship = {
    homeManager =
      {
        config,
        osConfig ? { },
        pkgs,
        ...
      }:
      {
        programs.starship = {
          enable = true;
          presets = [ "nerd-font-symbols" ];
          settings.custom.nix-config = {
            description = "Shows the current nix config status";
            shell = [ "${pkgs.bash}/bin/bash" ];
            style = "bold blue";
            ignore_timeout = true;
            when = true;
            # Accumulate all applicable indicators into $symbols.
            # Both the dirty marker and the branch-status marker may appear
            # at the same time (e.g. uncommitted changes on a non-main rev).
            command =
              let
                dirtyPart = if isDirty then ''symbols="''${symbols}!"'' else "";
                tokenPath = lib.attrByPath [ "age" "secrets" "nix-access-tokens" "path" ] (
                  lib.attrByPath [ "age" "secrets" "nix-access-tokens" "path" ] "" config
                ) osConfig;
                apiPart =
                  if rev != null then
                    ''
                      github_token=""
                      if [ -n "${tokenPath}" ] && [ -r "${tokenPath}" ]; then
                        while IFS= read -r line; do
                          if [[ "$line" =~ ^[[:space:]]*access-tokens[[:space:]]*=[[:space:]]*github\.com=(.+)$ ]]; then
                            github_token="''${BASH_REMATCH[1]}"
                          fi
                        done < "${tokenPath}"
                      fi

                      # Compare our pinned revision against main on GitHub to determine
                      # whether we are behind, diverged, or up-to-date.  Results are
                      # cached in ~/.cache/starship/ with a 60-minute TTL so that we
                      # do not hit the GitHub API on every prompt render.
                      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/starship"
                      cache_file="$cache_dir/nix-config-${rev}"

                      if [ -f "$cache_file" ] && [ -z "$(${pkgs.findutils}/bin/find "$cache_file" -mmin +60 2>/dev/null)" ]; then
                        status=$(cat "$cache_file")
                      else
                        status=$(
                          retries=2
                          delay=0.5
                          while [ "$retries" -ge 0 ]; do
                            result=$(
                              if [ -n "$github_token" ]; then
                                auth_args=(-H "Authorization: token $github_token")
                              else
                                auth_args=()
                              fi
                              ${pkgs.curl}/bin/curl -sf \
                                --connect-timeout 2 --max-time 3 \
                                ''${auth_args[@]} \
                                "https://api.github.com/repos/OscarMarshall/dotfiles/compare/${rev}...main" |
                                ${pkgs.jq}/bin/jq -r '.status // empty' 2>/dev/null || true
                            )
                            if [ -n "$result" ]; then
                              printf '%s' "$result"
                              break
                            fi
                            retries=$((retries - 1))
                            sleep "$delay"
                          done
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
                        behind | diverged) symbols="''${symbols}" ;;
                      esac
                    ''
                  else
                    "";
              in
              ''
                symbols=""
                ${apiPart}
                ${dirtyPart}
                if [ -n "$symbols" ]; then
                  echo "$symbols"
                fi
              '';
          };
        };
      };
  };
}
