{ lib, self, ... }:
let
  isDirty = self ? dirtyRev;
  # Extract the base commit SHA: self.rev when clean, or strip the "-dirty" suffix
  # from self.dirtyRev (available in Nix >= 2.11) when dirty.
  rev = self.rev or (if self ? dirtyRev then builtins.substring 0 40 self.dirtyRev else null);
in
{
  my.auto-upgrade = { allowReboot }: {
    nixos = { config, pkgs, ... }: {
      system.autoUpgrade = {
        inherit allowReboot;
        enable = true;
        flake = "github:OscarMarshall/dotfiles";
      };

      # Skip this run - rather than failing it - when the checkout this generation was
      # switched from isn't cleanly at (or behind) main's tip: uncommitted changes (dirty),
      # unpushed/unmerged commits (behind), diverged history (diverged), or an unknown compare
      # result (e.g. transient API failure, rate limit, or a rev GitHub can't find). Otherwise
      # the timer would silently switch a host back to main mid-test. Being merely behind main
      # (the normal case the timer exists to fix) is not blocked - this is an allow-list so
      # anything other than that confirmed-safe status fails closed.
      systemd.services.nixos-upgrade.serviceConfig.ExecCondition = pkgs.writeShellScript "nixos-upgrade-on-main" ''
        ${
          if rev != null then
            ''
              github_token="$(${pkgs.coreutils}/bin/cat ${config.age.secrets.nix-github-access-token.path} 2>/dev/null || true)"
              status=$(
                ${pkgs.curl}/bin/curl -sf \
                  --connect-timeout 2 --max-time 3 \
                  ''${github_token:+-H "Authorization: token $github_token"} \
                  "https://api.github.com/repos/OscarMarshall/dotfiles/compare/${rev}...main" |
                  ${pkgs.jq}/bin/jq -r '.status // empty' 2>/dev/null || true
              )
            ''
          else
            ""
        }

        case "$status" in
          ahead | identical) ;;
          *) exit 1 ;;
        esac

        ${lib.optionalString isDirty "exit 1"}
      '';
    };
  };
}
