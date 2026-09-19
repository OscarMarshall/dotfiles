let
  pname = "chart-manager";
  version = "1.3.7";
in
{
  my.chart-manager = {
    # Not in nixpkgs - upstream (https://github.com/xlzipx/clone-hero-chart-manager, distributed
    # from https://chartmanager.pages.dev/) only ships electron-builder artifacts (AppImage on
    # Linux, dmg/exe elsewhere), so wrap the Linux AppImage ourselves. Pinned by hand; bump
    # `version`/`hash` together for updates (`nix store prefetch-file` on the new release's
    # `CHM-<version>-linux-x86_64.AppImage` asset gives the new hash).
    hmLinux = { pkgs, ... }: {
      home.packages = [
        (
          let
            appimageContents = pkgs.appimageTools.extract { inherit pname src version; };
            src = pkgs.fetchurl {
              hash = "sha256-54/IPYDgEWw3gHZLor58GZw842qhhqRJRjKANjroMUc=";
              url = "https://github.com/xlzipx/clone-hero-chart-manager/releases/download/v${version}/CHM-${version}-linux-x86_64.AppImage";
            };
          in
          pkgs.appimageTools.wrapType2 {
            inherit pname src version;

            extraInstallCommands = ''
              install -Dm444 ${appimageContents}/chm.desktop -t $out/share/applications
              substituteInPlace $out/share/applications/chm.desktop \
                --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} --no-sandbox %U'
              cp -r ${appimageContents}/usr/share/icons $out/share
            '';

            meta = {
              description = "Search, download and convert Clone Hero charts from RhythmVerse and Chorus Encore";
              homepage = "https://chartmanager.pages.dev/";
              license = pkgs.lib.licenses.mit;
              mainProgram = pname;
              platforms = [ "x86_64-linux" ];
            };
          }
        )
      ];
    };
  };
}
