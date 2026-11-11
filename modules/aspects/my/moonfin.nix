{
  my.moonfin = { user, ... }: {
    # Jellyfin client (https://github.com/Moonfin-Client/Moonfin-Core), pairing with the Moonfin
    # server plugin jellyfin.nix installs. Not in nixpkgs, and upstream is a Flutter app with
    # vendored media_kit/libmpv forks - building that from source is a project of its own, so this
    # wraps upstream's own AppImage release instead, pinned by hand like any other `fetchurl`.
    homeManager =
      { lib, pkgs, ... }:
      let
        appimageContents = pkgs.appimageTools.extract { inherit pname src version; };
        pname = "moonfin";
        src = pkgs.fetchurl {
          hash = "sha256-s+Lqu6jODUFJazR3Jga6pBXggcUODh/GHzVuJvR0F+o=";
          url = "https://github.com/Moonfin-Client/Moonfin-Core/releases/download/${version}/Moonfin_Linux_v${version}.AppImage";
        };
        version = "3.0.0";
      in
      {
        home.packages = [
          (pkgs.appimageTools.wrapType2 {
            inherit pname src version;

            extraInstallCommands = ''
              install -Dm444 -t $out/share/applications ${appimageContents}/usr/share/applications/org.moonfin.linux.desktop
              install -Dm444 -t $out/share/icons/hicolor/512x512/apps ${appimageContents}/usr/share/icons/hicolor/512x512/apps/org.moonfin.linux.png
            '';

            # What the AppImage leaves to the host but appimageTools' default FHS env lacks
            # (libflutter_linux_gtk needs epoxy). Still missing after this: libjvm.so, only for
            # libdartjni.so's Android-side JNI bridge, never loaded on Linux.
            extraPkgs =
              pkgs: with pkgs; [
                libepoxy
                libffi
                libxv
                pcre2
              ];

            meta = {
              description = "Jellyfin client";
              homepage = "https://github.com/Moonfin-Client/Moonfin-Core";
              license = lib.licenses.gpl2Only;
              mainProgram = pname;
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
