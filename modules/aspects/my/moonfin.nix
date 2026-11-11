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
        src = inputs.moonfin-src;
      in
      {
        home.packages = [
          (pkgs.flutter347.buildFlutterApplication {
            inherit src;
            # Reads pubspec.lock via import-from-derivation, so it never needs regenerating by hand.
            autoPubspecLock = "${src}/pubspec.lock";

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

            # pubspec.lock's `source: git` deps (upstream's own forks). The one part a `moonfin-src`
            # bump can still break: when upstream moves one of these refs, set its hash to "" and
            # rebuild to get the new one.
            gitHashes = {
              background_downloader = "sha256-4EGBC6cyOAmK9BLs4B9iYmeYuzmoIAQHuepr4PzRguE=";
              media_kit_libs_windows_video = "sha256-0DEfXGih/WsbHp8oCbsjCPgLiloDMYAXeaqwReC3tH0=";
              media_kit_video = "sha256-0DEfXGih/WsbHp8oCbsjCPgLiloDMYAXeaqwReC3tH0=";
            };

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
