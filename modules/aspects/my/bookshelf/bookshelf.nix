{ den, ... }:
let
  # Bookshelf's upstream nixpkgs module (`services.readarr`) is a singleton option — it can't be enabled twice with
  # different settings in one host config. Den has the same constraint one level up: two `includes` entries for the
  # *same* named aspect (e.g. two `(bookshelf { ... })` calls) are treated as the same aspect identity and merged
  # last-write-wins, not as two separate instances (see `den.lib.aspects.fx.identity`, which keys resolved nodes by
  # aspect name). So instead of parameterizing one `my.bookshelf` aspect, we define one genuinely-distinct named
  # aspect per instance (`my.bookshelf-ebooks`, `my.bookshelf-audiobooks`), sharing this builder.
  #
  # Rather than hand-rolling a systemd unit that mirrors what `services.readarr` does (and risking it silently
  # drifting from upstream as nixpkgs' module evolves), we evaluate that module for real, once per instance, in an
  # isolated NixOS system built just for this purpose, then graft its computed `systemd.services.readarr` (renamed)
  # and `systemd.tmpfiles.settings` into our actual host config. This costs real extra eval time (a full NixOS module
  # tree gets evaluated per instance, on top of the real `harmony` one) but means there is nothing to keep in sync —
  # whatever nixpkgs' readarr module currently does, ours does too. `users.users`/`users.groups` are NOT sourced this
  # way: the module only auto-creates a user when `cfg.user == "readarr"` (its default), which isn't true here since
  # each instance needs its own dedicated user, so those stay hand-declared below exactly as before.
  mkBookshelfInstance =
    {
      instance,
      label,
      description,
      port,
    }:
    { administrators }:
    let
      user = "bookshelf-${instance}";
      dataDir = "/metalminds/${user}";
      hostName = "${user}.harmony.silverlight-nex.us";
      apiKeySecret = "${user}-api-key";
      envSecret = "${user}.env";
    in
    {
      # .NET 6 is EOL, so both the SDK (needed to build Bookshelf from source) and the ASP.NET Core
      # runtime it's wrapped with are flagged as insecure by nixpkgs' vulnerability roundup; Nix
      # refuses to even evaluate them otherwise. Bookshelf hasn't moved off net6.0 upstream.
      includes = [
        (den._.insecure [
          "dotnet-sdk-6.0.428"
          "aspnetcore-runtime-6.0.36"
        ])
      ];

      virtual-host = {
        name = user;
        url = hostName;
        inherit port;
      };

      homepage-entry = {
        group = "Media";
        label = "Bookshelf (${label})";
        inherit description;
        href = "https://${hostName}";
      };

      secrets = { secrets, ... }: {
        ${apiKeySecret} = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 16";
          intermediary = true;
        };
        ${envSecret}.generator = {
          dependencies = {
            ${apiKeySecret} = secrets.${apiKeySecret};
          };
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'READARR__AUTH__APIKEY="%s"\n' "$(${decrypt} ${lib.escapeShellArg deps.${apiKeySecret}.file})"
            '';
        };
      };

      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          # A from-scratch, throwaway NixOS system whose sole purpose is evaluating the real
          # `services.readarr` module with our per-instance settings, so we can lift its computed
          # systemd unit instead of reimplementing it. `fileSystems."/"`/`boot.loader.grub.enable`/
          # `system.stateVersion` are only present because unrelated parts of the base module list
          # unconditionally read them during eval — they have no bearing on the readarr module
          # itself and never reach the real host config. Passing our real `pkgs` through (rather
          # than a bare `system` string) avoids re-evaluating all of nixpkgs a second time.
          readarrConfig =
            (import (pkgs.path + "/nixos/lib/eval-config.nix") {
              inherit pkgs;
              # `system` defaults to `builtins.currentSystem`, which is unavailable under pure flake
              # evaluation; passing `pkgs` already sets `nixpkgs.pkgs`, so tell it not to bother.
              system = null;
              modules = [
                {
                  services.readarr = {
                    enable = true;
                    package = pkgs.callPackage ./_package.nix { };
                    inherit dataDir;
                    user = user;
                    group = user;
                    environmentFiles = [ config.age.secrets.${envSecret}.path ];
                    settings.server.port = port;
                  };
                  system.stateVersion = "25.05";
                  fileSystems."/" = {
                    device = "/dev/null";
                    fsType = "tmpfs";
                  };
                  boot.loader.grub.enable = false;
                }
              ];
            }).config;
        in
        {
          users.users = {
            ${user} = {
              isSystemUser = true;
              group = user;
              extraGroups = [ "qbittorrent" ];
            };
          }
          // (lib.genAttrs administrators (_: {
            extraGroups = [ user ];
          }));
          users.groups.${user} = { };

          systemd.tmpfiles.settings = readarrConfig.systemd.tmpfiles.settings;

          # Deliberately NOT `readarrConfig.systemd.services.readarr // { ... }`: that record's
          # fields (e.g. `serviceConfig`) are themselves submodule values whose type-checking
          # machinery closes over sibling options (`startLimitBurst` et al) from the *sub-eval's*
          # own "readarr" unit instance. Merging the whole record wholesale drags those closures in
          # and they blow up once our real host's systemd renderer forces them, since those sibling
          # options were never set there either. Lifting only the plain, already-resolved leaf
          # values we actually want avoids that entirely, while still tracking whatever nixpkgs'
          # readarr module currently computes for them.
          systemd.services.${user} = {
            description = "Bookshelf (${instance})";
            after = readarrConfig.systemd.services.readarr.after;
            wantedBy = readarrConfig.systemd.services.readarr.wantedBy;
            # `PATH` is generic infrastructure the sub-eval's own copy of
            # nixos/modules/system/boot/systemd.nix adds to every unit by default; our real host's
            # copy of that same module already does the same for this unit, so excluding it here
            # avoids a conflicting-definition clash. Everything else is the servarr-specific
            # `READARR__...` settings we actually want.
            environment = removeAttrs readarrConfig.systemd.services.readarr.environment [ "PATH" ];
            serviceConfig = {
              inherit (readarrConfig.systemd.services.readarr.serviceConfig)
                Type
                User
                Group
                EnvironmentFile
                ExecStart
                Restart
                ;
              RequiresMountsFor = [ dataDir ];
            };
          };
        };
    };
in
{
  my.bookshelf-audiobooks = mkBookshelfInstance {
    instance = "audiobooks";
    label = "Audiobooks";
    description = "Audiobook manager";
    port = 8788;
  };
  my.bookshelf-ebooks = mkBookshelfInstance {
    instance = "ebooks";
    label = "Ebooks";
    description = "Ebook manager";
    port = 8787;
  };
}
