{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  nodejs,
  curl,
  icu,
  libmediainfo,
  openssl,
  sqlite,
  zlib,
}:

buildDotnetModule (finalAttrs: {
  pname = "bookshelf";
  version = "0-unstable-2026-02-04";

  # Bookshelf (https://github.com/pennydreadful/bookshelf) is a near-unmodified fork of Readarr: same C#/.NET 6
  # codebase, namespace still `NzbDrone`, binary still literally named `Readarr`. There are no upstream GitHub
  # releases, so unlike nixpkgs' own `readarr` package (which fetches a prebuilt release tarball), this builds from
  # source.
  src = fetchFromGitHub {
    owner = "pennydreadful";
    repo = "bookshelf";
    rev = "c21c4134fdb710481ed69db05bf943b0acdbbf60"; # develop branch
    hash = "sha256-dHQLZVFKvOz7BD6C7qxmlns0eDgLD/+K6CLMWF1f+cQ=";
  };

  # The Servarr-standard TypeScript/webpack frontend uses Yarn 1 (classic), pinned via the `volta` field in
  # package.json (node 20.11.1, yarn 1.22.19).
  yarnOfflineCache = fetchYarnDeps {
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-lmtvDXf745fQN67MtZ5muIFyT3e41XYQELHHStgLauQ=";
  };

  nativeBuildInputs = [
    nodejs
    yarnConfigHook
  ];

  # The project's NuGet.config lives at src/NuGet.config (since the sln/csprojs are all under src/), which `dotnet
  # restore` finds fine (it walks up from the project file's directory). But nixpkgs' `nuget-to-json` (used by
  # `passthru.fetch-deps` to regenerate nugetDeps.json) invokes `dotnet nuget list source` from the *derivation's*
  # working directory (the repo root), where it would only ever see the default nuget.org source and silently miss
  # the four Servarr Azure DevOps feeds - producing bogus "couldn't find <pkg> <version>" errors for every package
  # sourced from those feeds. Mirroring the config file at the repo root fixes source discovery for both tools.
  postPatch = ''
    cp src/NuGet.config NuGet.config
  '';

  # Only build the console/posix entry point (`Readarr.Console.csproj`, which is what gets built for non-Windows
  # targets upstream) rather than the whole solution via the custom `PublishAllRids` MSBuild target that build.sh
  # uses - buildDotnetModule's standard restore/build/publish flow handles a single project directly, and this
  # project's dependency graph never pulls in the Windows-only projects (the WinForms tray app, the Windows service
  # helpers) that would otherwise need a Windows desktop workload to build.
  projectFile = "src/NzbDrone.Console/Readarr.Console.csproj";
  # If regenerating this from `passthru.fetch-deps`: drop any entries also present in
  # `dotnet-sdk.targetPackages.linux-x64` below (as of 6.0.36: Microsoft.NETCore.App.Runtime.linux-x64,
  # Microsoft.AspNetCore.App.Runtime.linux-x64, Microsoft.NETCore.App.Host.linux-x64, and the three
  # runtime.linux-x64.Microsoft.NETCore.DotNetHost{,Policy,Resolver} + .Runtime.Mono variants). Those
  # packs are already bundled in dotnet-sdk/dotnet-runtime and get linked into the NuGet fallback
  # folder unconditionally by buildDotnetModule's configureNuget phase; having them also listed here
  # makes it try to symlink the same destination twice and fail with "ln: failed to create symbolic
  # link ...: File exists" (hit this twice across two of these packages before checking the full set).
  nugetDeps = ./_deps.json;
  runtimeId = "linux-x64";

  dotnet-sdk = dotnetCorePackages.sdk_6_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_6_0;

  # Matches nixpkgs' own `readarr` package's LD_LIBRARY_PATH wrapping.
  runtimeDeps = [
    curl
    icu
    libmediainfo
    openssl
    sqlite
    zlib
  ];

  # Build the webpack frontend after the backend has compiled. Output lands at `_output/UI` (see
  # frontend/build/webpack.config.js), matching what build.sh's PackageFiles() expects.
  postBuild = ''
    yarn --offline run build --env production
  '';

  postInstall = ''
    cp -r _output/UI "$out/lib/${finalAttrs.pname}/UI"
  '';

  # NOTE: Deliberately not building Readarr.Update (the self-updater subdir). Bookshelf has no release feed of its
  # own to update from, so the built-in update mechanism can never find/download an update package and thus should
  # never actually try to invoke the updater binary - worst case is a harmless failed update-check log line. Building
  # it would mean publishing a second project (doubling nuget restore/build time) for no practical benefit under a
  # Nix-managed deployment where updates are handled by rebuilding this derivation.

  meta = {
    description = "Book and audiobook collection manager (a fork of Readarr)";
    homepage = "https://github.com/pennydreadful/bookshelf";
    license = lib.licenses.gpl3Only;
    mainProgram = "Readarr";
    platforms = [ "x86_64-linux" ];
  };
})
