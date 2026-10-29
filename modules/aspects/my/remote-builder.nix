# A *client*-side aspect: makes this host offload builds to another host's Nix daemon over SSH
# (`nix.distributedBuilds`) - CPU offload to a beefier always-on machine.
#
# The private half of the SSH keypair is a dedicated secret per builder (NOT the personal
# oscar-ssh-private-key, see oscar.nix) - remote build connections are made by the nix-daemon
# (root), not the interactive user, so the key has to be root-readable at daemon-start. The
# corresponding public key's `authorizedKeys` entry on the builder host is restricted to running
# `nix-daemon --stdio` only (see harmony.nix) so this secret can't be used for a general login -
# it MUST be that and not `nix-store --serve`, to match `protocol = "ssh-ng"` below.
#
# Usage:
#   includes = [ (remote-builder { builder = "harmony"; hostName = "harmony"; system = "x86_64-linux"; maxJobs = 32; publicHostKey = "..."; }) ];
#
# The keypair is an agenix-rekey generated secret (`agenix generate`, then `agenix rekey -a`), one
# per builder, shared by every client that includes this with the same `builder`. Its public half
# lands next to it as `secrets/generated/remote-builder-<builder>-ssh-key.pub`, which the builder
# host reads straight into its authorizedKeys (see harmony.nix) - nothing to hand-copy.
{
  my.remote-builder =
    {
      # Stable identifier for the secret filename - deliberately separate from `hostName` (the
      # address actually dialed), which can change (e.g. a LAN alias swapped for a MagicDNS name)
      # without that renaming/orphaning the secret and its already-rekeyed copies.
      builder,
      hostName,
      maxJobs,
      # base64 of `ssh-keyscan -t ed25519 <hostName>`'s output line (key + trailing newline) - same
      # shape nix.buildMachines.*.publicHostKey docs describe as `base64 -w0 ssh_host_*_key.pub`.
      # Pins the builder's host key here instead of relying on root's ~/.ssh/known_hosts.
      publicHostKey,
      system,
      speedFactor ? 1,
      sshUser ? "oscar",
      supportedFeatures ? [ ],
    }:
    let
      secretName = "remote-builder-${builder}-ssh-key";
    in
    {
      os = { config, ... }: {
        nix = {
          buildMachines = [
            {
              inherit
                hostName
                maxJobs
                publicHostKey
                speedFactor
                sshUser
                supportedFeatures
                system
                ;

              protocol = "ssh-ng";
              sshKey = config.age.secrets.${secretName}.path;
            }
          ];

          distributedBuilds = true;
          # Lets the builder fetch missing inputs from the binary caches itself rather than having
          # this host upload them over the tailnet - far faster when this host is a laptop on a slow
          # connection away from home. CI's own `builders` line (.github/workflows/test.yml) sets
          # the same.
          settings.builders-use-substitutes = true;
        };
      };

      # Same `ssh-keygen` call as agenix-rekey's built-in `ssh-ed25519` generator, but not that
      # generator itself: it bakes the generating host's name into the key comment, so melaan's and
      # tensoon's definitions of this one shared file would differ and `agenix generate` refuses
      # that. A fixed comment keeps them identical, and the `.pub` is written alongside for the
      # builder's authorizedKeys.
      secrets.${secretName}.generator.script =
        {
          lib,
          pkgs,
          file,
          ...
        }:
        ''
          priv=$(exec 3>&1; ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg "remote-builder@${builder}"} -f /proc/self/fd/3 <<<y >/dev/null 2>&1; true)
          ${pkgs.openssh}/bin/ssh-keygen -y -f /dev/stdin <<< "$priv" > ${
            lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")
          }
          echo "$priv"
        '';
    };
}
