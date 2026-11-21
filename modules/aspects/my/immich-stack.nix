# Immich Stack (majorfi.github.io/immich-stack) - groups related Immich assets (RAW+JPEG pairs,
# bursts, edits) into stacks using its default criteria: same base filename (before `~`/`.`) and
# capture time within one second. Expects immich.nix on the same host, reached over loopback.
#
# One-time manual setup, per Immich user whose library should be stacked: Account Settings -> API
# Keys -> "New API Key" with at least `user.read`, `asset.read`, `stack.read`, `stack.create`,
# `stack.update` and `stack.delete`. Then `agenix edit secrets/immich-stack-api-key.age` (needs the
# YubiKey) to store it - several users' keys go comma-separated on one line - and `agenix rekey -a`
# to make it available to the host.
{
  my.immich-stack =
    {
      # systemd calendar expression (systemd.time(7)) for each run.
      interval ? "hourly",
    }:
    {
      nixos = { config, pkgs, ... }: {
        systemd = {
          services.immich-stack = {
            description = "Immich Stack";
            after = [ "immich-server.service" ];

            environment = {
              API_KEY_FILE = "%d/api-key";
              API_URL = "http://${config.services.immich.host}:${toString config.services.immich.port}/api";
              # A one-shot run per timer tick, rather than its own long-running `cron` mode, so
              # each run's success/failure shows up as a systemd unit result.
              RUN_MODE = "once";
            };

            serviceConfig = {
              DynamicUser = true;

              ExecStart = pkgs.lib.getExe (
                pkgs.buildGoModule (finalAttrs: {
                  pname = "immich-stack";
                  # Upstream builds `./cmd/...` to `immich-stack`; Go names it after the directory.
                  postInstall = "mv $out/bin/cmd $out/bin/immich-stack";

                  src = pkgs.fetchFromGitHub {
                    hash = "sha256-mHSILgIuEzhlGu9eTjJNNQzrycxGgbzgWw4yNNnPyCg=";
                    owner = "majorfi";
                    repo = "immich-stack";
                    tag = "v${finalAttrs.version}";
                  };

                  subPackages = [ "cmd" ];
                  # Upstream commits its own `vendor/` directory.
                  vendorHash = null;
                  version = "0.2.44";
                  meta.mainProgram = "immich-stack";
                })
              );

              # Read by systemd itself, not the dynamic user, so the default root-only ownership
              # of the decrypted secret is fine.
              LoadCredential = "api-key:${config.age.secrets.immich-stack-api-key.path}";
              Type = "oneshot";
            };
          };

          timers.immich-stack = {
            timerConfig = {
              OnCalendar = interval;
              Persistent = true;
            };

            wantedBy = [ "timers.target" ];
          };
        };
      };

      secrets.immich-stack-api-key.rekeyFile = ../../../secrets/immich-stack-api-key.age;
    };
}
