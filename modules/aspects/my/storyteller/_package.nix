{
  lib,
  stdenv,
  fetchFromGitLab,
  fetchurl,
  yarn-berry_4,
  nodejs_24,
  makeWrapper,
  autoPatchelfHook,
  python3,
  pkg-config,
  openssl,
  sqlite,
  vips,
}:

let
  yarn-berry = yarn-berry_4;
  nodejs = nodejs_24;

  # Pinned to the HEAD of the `main` branch at the time this package was written. Storyteller
  # doesn't cut stable releases/tags on a predictable cadence, so we track a specific commit
  # instead. Bump by re-running the fetchFromGitLab/fetchYarnBerryDeps hash dance below.
  rev = "c6f02ab4c3d79faca35c40e9d43c1153a7b5205c";
  version = "0-unstable-2026-07-07";

  # whisper.cpp build/version pin, mirrored from libraries/ghost-story/src/constants.ts
  # (WHISPER_CPP_UPSTREAM_VERSION + WHISPER_CPP_PATCH_LEVEL) at the pinned rev above.
  whisperCppVersion = "1.8.3-st.2";
  whisperVariant = "linux-x64-cpu";
  whisperModel = "tiny.en";

  # Prebuilt whisper.cpp binary tarball + GGML model, published by the Storyteller project
  # itself to GitLab's generic/ml_models package registries (see
  # libraries/ghost-story/src/cli/config.ts's getBinaryDownloadUrl/getModelDownloadUrl). These
  # are fetched here as plain FODs instead of at runtime, so the service never needs network
  # access to become functional. Placed at the exact paths ghost-story's FileSystem utilities
  # expect (getWhisperBaseDir/getModelDir, both under $HOME/.local/share/ghost-story) via the
  # storyteller.nix systemd unit's systemd.tmpfiles "C" rules.
  whisperCppTarball = fetchurl {
    url = "https://gitlab.com/api/v4/projects/67994333/packages/generic/whisper-cpp/${whisperCppVersion}/whisper-cpp-${whisperVariant}.tar.gz";
    hash = "sha256-659JXuIdRbprUZxr1tLQjmFsLs5IvMRpWQGBBwV+da0=";
  };

  # whisper.cpp's own binaries (whisper-cli et al.) are ordinary dynamically-linked ELF
  # executables built for a generic glibc Linux, not NixOS -- they need their ELF interpreter
  # and RPATH patched via autoPatchelfHook before they'll run at all.
  whisperCpp = stdenv.mkDerivation {
    pname = "whisper-cpp-storyteller";
    version = whisperCppVersion;

    src = whisperCppTarball;
    sourceRoot = ".";

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r bin $out/
      runHook postInstall
    '';

    meta = {
      description = "whisper.cpp build vendored by Storyteller for forced alignment/transcription";
      homepage = "https://github.com/ggerganov/whisper.cpp";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };

  whisperModelFile = fetchurl {
    url = "https://gitlab.com/api/v4/projects/67994333/packages/ml_models/2007349/files/ggml-${whisperModel}.bin";
    hash = "sha256-kh5M+Ghv3Zk9zQgaXaW2w2W/3hFi5ysI11rHUomSCx8=";
  };

  # Readium's CLI is normally vendored into Storyteller's own Docker image straight from
  # ghcr.io/readium/readium:0.6.5 (COPY --from=...). We can't pull arbitrary OCI images here
  # (and ghcr.io isn't reachable from this sandbox at all), but readium/cli publishes the exact
  # same statically-linked binary as a plain GitHub release asset, which is much more Nix-native
  # to fetch. Version matches applications/web/install-readium-cli.sh's default.
  readium = stdenv.mkDerivation {
    pname = "readium-cli";
    version = "0.6.5";

    src = fetchurl {
      url = "https://github.com/readium/cli/releases/download/v0.6.5/readium_linux_x86_64.tar.gz";
      hash = "sha256-fP+5JHX1NmQfLlk6Jpl7U4TVFJjf0dL+nh7VeBfRnVE=";
    };

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      # Extract the whole archive rather than naming ./readium as the member to extract: the
      # tarball actually stores the entry as a bare "readium" (no leading ./), and at least one
      # tar implementation encountered in CI treats that as a non-match against "./readium" and
      # fails with "Not found in archive" instead of just extracting everything.
      mkdir -p $out/bin extracted
      tar -xzf $src -C extracted
      install -Dm755 extracted/readium $out/bin/readium

      runHook postInstall
    '';

    # Statically linked, so no autoPatchelfHook needed.

    meta = {
      description = "CLI for generating Readium Web Publication Manifests, used by Storyteller";
      homepage = "https://github.com/readium/cli";
      license = lib.licenses.bsd3;
      platforms = [ "x86_64-linux" ];
      mainProgram = "readium";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "storyteller";
  inherit version;

  src = fetchFromGitLab {
    domain = "gitlab.com";
    owner = "storyteller-platform";
    repo = "storyteller";
    inherit rev;
    # Needed so that libraries/align/prebuilds/** (native `.node` addon, checked in via Git LFS)
    # comes down correctly -- GitLab's tarball/archive API (fetchzip, fetchFromGitLab's default)
    # does not resolve LFS pointers, only a real `git clone` + `git lfs pull` does.
    forceFetchGit = true;
    fetchLFS = true;
    hash = "sha256-69o1lXPX3gy2vXl7BGWv7TZD8VAq25X61kxpeKwm3p4=";
  };

  missingHashes = ./missing-hashes.json;
  offlineCache = yarn-berry.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-Dcausaeqt96/nU2G+Op3wK4FUYiiqS3gpgeFa130OuI=";
  };

  nativeBuildInputs = [
    nodejs
    yarn-berry
    yarn-berry.yarnBerryConfigHook
    makeWrapper
    autoPatchelfHook
    python3
    pkg-config
  ];

  # Runtime libs for native addons that fall back to compiling from source (better-sqlite3,
  # argon2) or that autoPatchelfHook needs to satisfy for prebuilt platform-specific `.node`
  # addons pulled in as optional dependencies (sharp, @parcel/watcher, @node-rs/*,
  # @reflink/reflink).
  buildInputs = [
    stdenv.cc.cc.lib
    openssl
    sqlite
    vips
  ];

  env = {
    NODE_ENV = "production";
    NEXT_TELEMETRY_DISABLED = "1";
    # sharp auto-detects the system libvips (present in buildInputs, needed by other native
    # addons) via pkg-config and prefers building itself from source against it over using its
    # own prebuilt binary -- which then needs node-gyp, not resolvable as a yarn script in this
    # monorepo ("Usage Error: Couldn't find a script name "node-gyp" in the top-level"). Force it
    # to use the prebuilt instead.
    SHARP_IGNORE_GLOBAL_LIBVIPS = "1";
  };

  buildPhase = ''
    runHook preBuild

    # Storyteller's own SQLite UUID extension, normally compiled by the Dockerfile with the
    # system gcc; do the same here.
    ${stdenv.cc}/bin/gcc -g -fPIC -rdynamic -shared applications/web/sqlite/uuid.c -o applications/web/sqlite/uuid.c.so

    # Needed by some build-time codegen in the web app, mirroring the Dockerfile.
    export SQLITE_NATIVE_BINDING="$PWD/node_modules/better-sqlite3/build/Release/better_sqlite3.node"

    yarn workspaces foreach -Rpt --from @storyteller-platform/web --exclude @storyteller-platform/eslint run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app=$out/lib/storyteller/applications/web
    mkdir -p "$app"

    # next.config.js sets `outputFileTracingRoot` to the monorepo root (three levels up from
    # applications/web/next.config.js), so the standalone output mirrors the full monorepo-relative
    # path: server.js lands at .../standalone/applications/web/server.js (i.e. under $app, not at
    # the root we copy into), while traced/hoisted node_modules lands at .../standalone/node_modules
    # (the root, NOT under $app). Both match this project's own Dockerfile exactly (WORKDIR
    # /app/.next/standalone/applications/web; SQLITE_NATIVE_BINDING under
    # /app/.next/standalone/node_modules, one level above that WORKDIR).
    cp -r applications/web/.next/standalone/. $out/lib/storyteller/

    cp -r applications/web/public "$app/public"
    mkdir -p "$app/.next"
    cp -r applications/web/.next/static "$app/.next/static"
    # Next.js writes its image-optimization/ISR/fetch cache under .next/cache by default, which
    # can't live in the read-only Nix store. storyteller.nix creates
    # /metalminds/storyteller/next-cache (writable, owned by the service user) and we point at it
    # here instead. This hardcodes this host's data-dir convention, matching how the rest of this
    # aspect (systemd unit, secrets) is already harmony-specific.
    ln -s /metalminds/storyteller/next-cache "$app/.next/cache"
    install -Dm755 applications/web/sqlite/uuid.c.so "$app/sqlite/uuid.c.so"
    cp -r applications/web/migrations "$app/migrations"

    mkdir -p "$app/scripts"
    cp -r docker-scripts/. "$app/scripts/"

    # esbuild worker bundles (background jobs run via worker_threads, not separate units).
    cp -r applications/web/work-dist "$app/work-dist"
    cp -r applications/web/file-write-dist "$app/file-write-dist"

    # The align native addon is required (via node-gyp-build) relative to the worker bundle,
    # not node_modules -- mirrors the Dockerfile's runner-stage COPY lines exactly.
    mkdir -p "$app/work-dist/@storyteller-platform/align/prebuilds"
    cp -r libraries/align/prebuilds/linux-x64 "$app/work-dist/@storyteller-platform/align/prebuilds/linux-x64"
    cp -r libraries/align/prebuilds/linux-arm64 "$app/work-dist/@storyteller-platform/align/prebuilds/linux-arm64"

    # Echogarden's ICU segmentation wasm naively resolves its files relative to work-dist/.
    cp node_modules/@echogarden/icu-segmentation-wasm/wasm/*.wasm "$app/work-dist/"

    # @parcel/watcher's native binary is loaded dynamically at runtime and isn't traced by
    # next.js into the standalone output; kuromoji's dict/ directory is resolved via
    # require.resolve at runtime by the bundled kuroshiro analyzer.
    mkdir -p "$out/lib/storyteller/node_modules"
    cp -r node_modules/@parcel "$out/lib/storyteller/node_modules/@parcel"
    cp -r node_modules/kuromoji "$out/lib/storyteller/node_modules/kuromoji"

    mkdir -p $out/bin
    {
      echo "#!${stdenv.shell}"
      echo "cd \"$app\" || exit 1"
      echo 'exec ${nodejs}/bin/node --enable-source-maps server.js "$@"'
    } > $out/bin/storyteller
    chmod +x $out/bin/storyteller

    wrapProgram $out/bin/storyteller \
      --set NODE_ENV production \
      --set NEXT_TELEMETRY_DISABLED 1 \
      --set STORYTELLER_WORKER worker.mjs \
      --set STORYTELLER_FILE_WRITE_WORKER fileWriteWorker.mjs \
      --set ERROR_ALIGN_NATIVE_BINDING "$app/work-dist/@storyteller-platform/align/" \
      --set SQLITE_NATIVE_BINDING "$out/lib/storyteller/node_modules/better-sqlite3/build/Release/better_sqlite3.node" \
      --prefix PATH : ${lib.makeBinPath [ readium ]}

    runHook postInstall
  '';

  passthru = {
    inherit
      readium
      whisperCpp
      whisperModelFile
      whisperCppVersion
      whisperVariant
      whisperModel
      ;
  };

  meta = {
    description = "Self-hosted ebook and audiobook platform with forced-alignment read-aloud";
    homepage = "https://gitlab.com/storyteller-platform/storyteller";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "storyteller";
  };
})
