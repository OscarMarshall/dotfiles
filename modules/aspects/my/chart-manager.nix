{ inputs, ... }: {
  # Tracks upstream's default branch (not a release tag), so `nix flake update
  # chart-manager-src` alone picks up new releases - no hand-maintained version/hash pin.
  flake-file.inputs.chart-manager-src = {
    url = "github:xlzipx/clone-hero-chart-manager";
    flake = false;
  };

  my.chart-manager = {
    # Not in nixpkgs, and upstream (https://github.com/xlzipx/clone-hero-chart-manager,
    # distributed from https://chartmanager.pages.dev/) only ships electron-builder artifacts
    # (AppImage on Linux, dmg/exe elsewhere) - built from `chart-manager-src` instead of fetching
    # one of those.
    hmLinux =
      { lib, pkgs, ... }:
      let
        inherit (builtins.fromJSON (builtins.readFile "${appSrc}/package.json")) version;
        appSrc = "${inputs.chart-manager-src}/app";
        # Upstream locks better-sqlite3 at 12.4.1, which predates its move to node-addon-api
        # (N-API) - it needs a prebuild matching Electron's *exact* ABI, and better-sqlite3 only
        # ever published one for Electron up to ~38 (older than any Electron major nixpkgs still
        # carries). 13.x's N-API rewrite is ABI-stable across every Node/Electron version - one
        # prebuild per platform, bundled in the npm tarball itself, no version chasing ever again.
        # Its public API is unchanged from 12.x (WiseLibs' migration was internal-only), and
        # chart-manager only uses the stable core (Database/prepare/exec/pragma/transaction), so
        # swapping in 13.x post-install is safe.
        betterSqlite3Prebuilt = pkgs.fetchurl {
          hash = "sha256-d+BRPcGkafs7zuxMf7WtP0AxCXh+2gW+BH7Bf9VoaMs=";
          url = "https://registry.npmjs.org/better-sqlite3/-/better-sqlite3-13.0.3.tgz";
        };
        chartManager = pkgs.buildNpmPackage {
          inherit pname version;
          buildInputs = [ pkgs.stdenv.cc.cc.lib ];

          installPhase = ''
            runHook preInstall

            # Upstream only lists `dependencies` (better-sqlite3, electron-updater, parse-sng,
            # zustand) as runtime - everything else (vite, typescript, electron itself, ...) is
            # `devDependencies` used only to produce `out/`. `npm prune` doesn't fully clear the
            # dev toolchain in this sandboxed, offline install (some packages survive despite not
            # being reachable from a `dependencies` edge - a known npm-offline quirk, not specific
            # to this package); harmless dead weight since nothing under `out/` requires them.
            npm prune --omit=dev --ignore-scripts

            mkdir -p $out/lib/chart-manager
            cp -r out node_modules package.json $out/lib/chart-manager/

            rm -rf $out/lib/chart-manager/node_modules/better-sqlite3
            mkdir -p $out/lib/chart-manager/node_modules/better-sqlite3
            tar -xzf ${betterSqlite3Prebuilt} -C $out/lib/chart-manager/node_modules/better-sqlite3 --strip-components=1
            find $out/lib/chart-manager/node_modules/better-sqlite3/prebuilds -type f ! -name 'linux-x64.node' -delete

            # `config.ts`'s `detectOnyxPath`/`detect7zDir` search (among other roots)
            # `$PORTABLE_EXECUTABLE_DIR/native/{onyx-linux,7zip-linux}` - normally set by
            # electron-builder's Windows portable target, but nothing stops us setting it
            # ourselves in the wrapper below to point at these.
            mkdir -p $out/lib/chart-manager/resources/native/onyx-linux $out/lib/chart-manager/resources/native/7zip-linux
            ln -s ${onyx}/bin/onyx $out/lib/chart-manager/resources/native/onyx-linux/onyx
            ln -s ${pkgs._7zz}/bin/7zz $out/lib/chart-manager/resources/native/7zip-linux/7zz

            install -Dm444 build/icon-1024.png $out/share/icons/hicolor/1024x1024/apps/chart-manager.png
            install -Dm444 ${./chart-manager.desktop} $out/share/applications/chart-manager.desktop

            makeWrapper ${pkgs.electron}/bin/electron $out/bin/chart-manager \
              --add-flags "$out/lib/chart-manager/out/main/index.js" \
              --add-flags "--no-sandbox" \
              --add-flags "--ozone-platform-hint=auto" \
              --set PORTABLE_EXECUTABLE_DIR "$out/lib/chart-manager/resources"

            runHook postInstall
          '';

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.autoPatchelfHook
          ];

          # `nix run nixpkgs#prefetch-npm-deps app/package-lock.json` gives the new hash after a
          # `chart-manager-src` update.
          npmDepsHash = "sha256-mRZUH1UYlI89gNXgGFPM0Ln6Gh48wjh+jQaFsoe2caM=";
          # `npm ci` already runs with --ignore-scripts by default (skips better-sqlite3's and
          # electron's own network-fetching postinstalls) - but buildNpmPackage's `npm rebuild`
          # right after does not, so it needs telling the same or it retries those offline.
          npmRebuildFlags = [ "--ignore-scripts" ];
          src = appSrc;

          meta = {
            description = "Search, download and convert Clone Hero charts from RhythmVerse and Chorus Encore";
            homepage = "https://chartmanager.pages.dev/";
            license = lib.licenses.mit;
            mainProgram = pname;
            platforms = [ "x86_64-linux" ];
          };
        };
        # Companion CLI tool electron-builder's own Linux build fetches at build time (see
        # upstream's .github/workflows/build-linux.yml) - own release cadence, unrelated to
        # chart-manager's, so pinned by hand same as any other `fetchurl`. Not built from source:
        # onyx is a large Haskell project vendoring a dozen C libraries (FFmpeg, libvorbis, FLAC,
        # FLTK, ...) as git submodules built via its own Docker/MSYS2/Homebrew-specific toolchain
        # - packaging that in Nix is a project of its own, disproportionate for a helper binary.
        # Fetching its AppImage is the same distribution path upstream's own CI uses.
        onyx = pkgs.appimageTools.wrapType2 {
          pname = "onyx";

          src = pkgs.fetchurl {
            hash = "sha256-rguRlAJASGEHvtX00v3+YWELAbFN+xQWLycyqIjK2vk=";
            url = "https://github.com/mtolly/onyx/releases/download/20251011/onyx-20251011-linux-x64.AppImage";
          };

          version = "20251011";
        };
        pname = "chart-manager";
      in
      {
        home.packages = [ chartManager ];
      };
  };
}
