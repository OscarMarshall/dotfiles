{ inputs, ... }: {
  # Tracks upstream's default branch (not a release tag - those switch between `3.0.0` and `v2.8.0`
  # styles), so `nix flake update moonfin-src` alone picks up new versions.
  flake-file.inputs.moonfin-src = {
    url = "github:Moonfin-Client/Moonfin-Core";
    flake = false;
  };

  my.moonfin = { user, ... }: {
    # Jellyfin client (https://github.com/Moonfin-Client/Moonfin-Core), pairing with the Moonfin
    # server plugin jellyfin.nix installs. Not in nixpkgs, and upstream only ships versioned release
    # artifacts (AppImage/deb/flatpak/...) with no stable URL to track - built from `moonfin-src`
    # instead.
    homeManager =
      { lib, pkgs, ... }:
      let
        # Same import-from-derivation `autoPubspecLock` does, done here so `gitHashes` below can read
        # it too - pubspec.lock never needs regenerating by hand.
        pubspecLock = lib.importJSON (
          pkgs.runCommand "moonfin-pubspec-lock-json" { nativeBuildInputs = [ pkgs.yq ]; } "yq . '${src}/pubspec.lock' > $out"
        );
        src = inputs.moonfin-src;
      in
      {
        home.packages = [
          (pkgs.flutter347.buildFlutterApplication {
            inherit pubspecLock src;

            buildInputs = with pkgs; [
              alsa-lib
              libass
              mpv-unwrapped
              webkitgtk_4_1
            ];

            # Upstream generates its desktop entry in build-linux.sh rather than keeping one in the
            # repo (assets/flathub/'s uses the Flathub app ID, which wouldn't match the window's
            # `org.moonfin.linux` class) - this mirrors the AppImage one.
            desktopItems = [
              (pkgs.makeDesktopItem {
                categories = [
                  "AudioVideo"
                  "Video"
                ];

                comment = "Jellyfin & Emby media client";
                desktopName = "Moonfin";
                exec = "moonfin %U";
                icon = "org.moonfin.linux";
                mimeTypes = [ "x-scheme-handler/moonfin" ];
                name = "org.moonfin.linux";
                startupWMClass = "org.moonfin.linux";
              })
            ];

            # pubspec.lock's `source: git` deps (upstream's own forks) need a hash pub doesn't record.
            # `builtins.fetchGit` needs none for a pinned rev, and its narHash is exactly what
            # pub2nix's `fetchgit` checks for (submodules included, matching fetchgit's default) -
            # so whatever refs a `moonfin-src` bump moves these to, nothing to update by hand.
            gitHashes = lib.mapAttrs (
              _: dep:
              (fetchGit {
                inherit (dep.description) url;
                allRefs = true;
                rev = dep.description.resolved-ref;
                submodules = true;
              }).narHash
            ) (lib.filterAttrs (_: dep: dep.source == "git") pubspecLock.packages);

            nativeBuildInputs = [ pkgs.copyDesktopItems ];
            pname = "moonfin";

            postInstall = ''
              install -Dm444 assets/icons/moonfin.png $out/share/icons/hicolor/512x512/apps/org.moonfin.linux.png
            '';

            # `version: 3.0.0+30000156` -> "3.0.0".
            version = lib.head (builtins.match ".*\nversion: ([^+\n]+).*" (builtins.readFile "${src}/pubspec.yaml"));

            meta = {
              description = "Jellyfin client";
              homepage = "https://github.com/Moonfin-Client/Moonfin-Core";
              license = lib.licenses.gpl2Only;
              mainProgram = "moonfin";
              platforms = [ "x86_64-linux" ];
            };
          })
        ];
      };

    # Server list, login tokens and settings. `preserve` (modules/aspects/my/preserve.nix) is inert
    # without my.preservation.
    preserve.users.${user.userName}.directories = [ ".local/share/org.moonfin.linux" ];
  };
}
