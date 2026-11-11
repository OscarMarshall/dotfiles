{ den, ... }:
let
  # pass-cli defaults to PROTON_PASS_LINUX_KEYRING=kernel, storing its DB encryption key in the
  # kernel key-retention service - which is wiped on every reboot, so a login never survives one.
  # `dbus` puts the key in the Secret Service (gnome-keyring) instead: file-backed and unlocked by
  # pam_gnome_keyring at password login (see my.noctalia-greeter). Paired with preserving
  # ~/.local/share/proton-pass-cli, the session then persists across reboots. A
  # fingerprint-only login leaves the keyring locked until it's unlocked.
  linuxKeyProvider = "dbus";
in
{
  my.proton-pass = { user, ... }: {
    includes = [ (den._.unfree [ "proton-pass-cli" ]) ];

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.proton-pass.secrets;
        pass-cli = lib.getExe' config.services.proton-pass-agent.package "pass-cli";
      in
      {
        # User secrets read out of Proton Pass, standing in for Home Manager-level agenix secrets:
        # `proton-pass.secrets.<name>.uri` in, `.path` out, same shape as `age.secrets.<name>.path`
        # so consumers just swap the attrset. `path` is the same unexpanded `${XDG_RUNTIME_DIR}/...`
        # form agenix's Home Manager paths use, so it still has to be expanded by a shell.
        options.proton-pass.secrets = lib.mkOption {
          default = { };

          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }: {
                options = {
                  path = lib.mkOption {
                    default = "\${XDG_RUNTIME_DIR}/proton-pass/${name}";
                    readOnly = true;
                    type = lib.types.str;
                  };

                  uri = lib.mkOption {
                    description = "`pass://<vault>/<item>/<field>` reference, by name or ID.";
                    type = lib.types.str;
                  };
                };
              }
            )
          );
        };

        config = {
          home.sessionVariables.PROTON_PASS_LINUX_KEYRING = linuxKeyProvider;
          services.proton-pass-agent.enable = true;

          # home.sessionVariables only reaches shells - systemd --user does not import it. Without
          # this the agent's `pass-cli ssh-agent start` falls back to the kernel provider while the
          # shell uses dbus; the two key stores diverge and every agent start rewrites pass-cli.db
          # with a key the shell can't read. Same value, one source, so they can't drift.
          systemd.user.services = {
            proton-pass-agent.Service.Environment = [ "PROTON_PASS_LINUX_KEYRING=${linuxKeyProvider}" ];

            # Materializes `proton-pass.secrets` once per login rather than having each consumer
            # call pass-cli itself: every lookup syncs with Proton's servers and takes ~5-9s, far too
            # slow for e.g. a wrapper around every `claude` launch. Files land on tmpfs, mode 0600
            # under a 0700 RuntimeDirectory that's removed again when the unit stops. Lookups run in
            # parallel (concurrent reads of pass-cli.db are fine). A logged-out session or a locked
            # keyring (fingerprint-only login, or a headless host with no Secret Service) fails the
            # unit and it retries; after `pass-cli login` the next retry picks everything up, or
            # `systemctl --user restart proton-pass-secrets` does it right away.
            proton-pass-secrets = lib.mkIf (cfg != { }) {
              Install.WantedBy = [ "default.target" ];

              Service = {
                Environment = [ "PROTON_PASS_LINUX_KEYRING=${linuxKeyProvider}" ];

                ExecStart = pkgs.writeShellScript "proton-pass-secrets" ''
                  set -u
                  umask 077

                  ${lib.concatMapAttrsStringSep "\n" (name: secret: ''
                    (
                      value=$(${pass-cli} item view ${lib.escapeShellArg secret.uri}) && [ -n "$value" ] &&
                        printf '%s' "$value" > "$RUNTIME_DIRECTORY"/${lib.escapeShellArg name}
                    ) || { echo "proton-pass-secrets: couldn't read ${name}" >&2; exit 1; } &
                  '') cfg}

                  status=0
                  for job in $(jobs -p); do
                    wait "$job" || status=1
                  done
                  exit "$status"
                '';

                RemainAfterExit = true;
                Restart = "on-failure";
                RestartSec = "5min";
                RuntimeDirectory = "proton-pass";
                RuntimeDirectoryMode = "0700";
                Type = "oneshot";
              };

              Unit.Description = "Read user secrets out of Proton Pass";
            };
          };
        };
      };

    # pass-cli's encrypted session DB (session.json, user_keys.enc, pass-cli.db). The DB key lives in
    # gnome-keyring (see linuxKeyProvider above) and persists via my.noctalia-greeter's
    # ~/.local/share/keyrings entry; this is the other half - without it pass-cli comes up logged out
    # every boot even with the key kept. `preserve` (modules/aspects/my/preserve.nix) is inert without
    # my.preservation.
    preserve.users.${user.userName}.directories = [ ".local/share/proton-pass-cli" ];
  };
}
