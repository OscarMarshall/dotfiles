{ self, ... }:
let
  isDirty = self ? dirtyRev;
  # Extract the base commit SHA: self.rev when clean, or strip the "-dirty" suffix
  # from self.dirtyRev (available in Nix >= 2.11) when dirty.
  rev = self.rev or (if self ? dirtyRev then builtins.substring 0 40 self.dirtyRev else null);
in
{
  my.starship.homeManager =
    {
      config,
      pkgs,
      osConfig ? { },
      ...
    }:
    {
      programs.starship = {
        enable = true;
        presets = [ "nerd-font-symbols" ];

        settings.custom.nix-config = {
          # Accumulate all applicable indicators into $symbols.
          # Both the dirty marker and the branch-status marker may appear
          # at the same time (e.g. uncommitted changes on a non-main rev).
          command =
            let
              apiPart =
                if rev != null then
                  ''
                    # Whether main on GitHub has moved ahead of our pinned revision, cached under
                    # ~/.cache/starship/. The prompt only ever *reads* the cache (instant); when it
                    # is missing or stale a detached background job refreshes it for next time, so a
                    # slow, offline, rate-limited, or not-yet-pushed revision never blocks the
                    # prompt. A real answer holds for 60 min; a failed fetch is stored as "unknown"
                    # and retried after 5.
                    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/starship"
                    cache_file="$cache_dir/nix-config-${rev}"

                    status=""
                    [ -f "$cache_file" ] && status=$(${pkgs.coreutils}/bin/cat "$cache_file" 2>/dev/null)

                    ttl=60
                    [ "$status" = unknown ] && ttl=5
                    if [ ! -f "$cache_file" ] || [ -n "$(${pkgs.findutils}/bin/find "$cache_file" -mmin +"$ttl" 2>/dev/null)" ]; then
                      github_token=${
                        if tokenPath != null then ''"$(${pkgs.coreutils}/bin/cat ${tokenPath} 2>/dev/null || true)"'' else ''""''
                      }
                      (
                        result=$(
                          ${pkgs.curl}/bin/curl -sf \
                            --connect-timeout 2 --max-time 4 \
                            ''${github_token:+-H "Authorization: token $github_token"} \
                            "https://api.github.com/repos/OscarMarshall/dotfiles/compare/${rev}...main" |
                            ${pkgs.jq}/bin/jq -r '.status // empty' 2>/dev/null || true
                        )
                        ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"
                        printf '%s' "''${result:-unknown}" > "$cache_file"
                      ) >/dev/null 2>&1 &
                    fi

                    case "$status" in
                      # main has commits our pinned revision doesn't.
                      ahead) symbols="''${symbols}⇣" ;;
                    esac
                  ''
                else
                  "";
              dirtyPart = if isDirty then ''symbols="''${symbols}!"'' else "";
              # Reuse the token already provisioned for authenticated Nix
              # flake fetches (modules/aspects/my/nix.nix) instead of
              # provisioning a second GitHub PAT just for this rate-limit
              # workaround.
              #
              # On host-embedded users (melaan/harmony/the MacBook), my.nix's
              # secret lives in the system (osConfig), not this home-manager
              # config; on a standalone home (dev203) it lives in this config
              # directly and osConfig is empty. Check both.
              tokenPath =
                let
                  osPath = osConfig.age.secrets.nix-github-access-token.path or null;
                in
                if osPath != null then osPath else config.age.secrets.nix-github-access-token.path or null;
            in
            ''
              symbols=""
              ${apiPart}
              ${dirtyPart}
              if [ -n "$symbols" ]; then
                echo ".$symbols"
              fi
            '';

          description = "Shows the current nix config status";
          ignore_timeout = true;
          shell = [ "${pkgs.bash}/bin/bash" ];
          style = "bold blue";
          when = true;
        };
      };
    };
}
