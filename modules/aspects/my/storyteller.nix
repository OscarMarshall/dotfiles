{ inputs, ... }:
let
  url = "storyteller.harmony.silverlight-nex.us";
  port = 8001;
  port' = toString port;
  readiumPort = 9000;
  dataDir = "/metalminds/storyteller";
  homeDir = "${dataDir}/home";
  ghostStoryDir = "${homeDir}/.local/share/ghost-story";
in
{
  # Tracks the pinned WHISPER_CPP_VERSION/whisperVariant that storyteller/_package.nix's
  # whisperCppVersion/whisperVariant must also match (see the doc comment on its whisperCppTarball
  # parameter) -- bump all three together when updating.
  flake-file.inputs.storyteller-whisper-cpp = {
    url = "https://gitlab.com/api/v4/projects/67994333/packages/generic/whisper-cpp/1.8.3-st.2/whisper-cpp-linux-x64-cpu.tar.gz";
    type = "tarball";
    flake = false;
  };

  my.storyteller = {
    virtual-host = {
      name = "storyteller";
      inherit url port;
    };

    homepage-entry = {
      group = "Media";
      label = "Storyteller";
      description = "Read-aloud book alignment";
      href = "https://${url}";
    };

    secrets.storyteller-secret-key.generator.script = "alnum";

    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        storyteller = pkgs.callPackage ./storyteller/_package.nix { whisperCppTarball = inputs.storyteller-whisper-cpp; };
      in
      {
        users.users.storyteller = {
          isSystemUser = true;
          group = "storyteller";
          description = "Storyteller service user";
        };
        users.groups.storyteller = { };

        # Storyteller's data (SQLite DB + imported books/audio) lives on the /metalminds ZFS
        # pool, matching this host's convention for other services. `whisper-cpp`'s binary and
        # default model are placed at the exact HOME-relative paths that libraries/ghost-story
        # expects (see FileSystem.ts's getAppDataDir/getWhisperBaseDir/getModelDir), prefetched
        # at build time by the package (package.nix's `whisperCpp`/`whisperModelFile`) so the
        # service never needs network access at runtime to become functional.
        systemd.tmpfiles.rules = [
          "d ${dataDir} 0750 storyteller storyteller -"
          # Next.js's on-disk cache (image optimization/ISR/fetch); package.nix symlinks
          # applications/web/.next/cache here since the Nix store itself is read-only.
          "d ${dataDir}/next-cache 0750 storyteller storyteller -"
          "d ${homeDir} 0750 storyteller storyteller -"
          "d ${ghostStoryDir} 0750 storyteller storyteller -"
          "d ${ghostStoryDir}/whisper-cpp 0750 storyteller storyteller -"
          "d ${ghostStoryDir}/whisper-cpp/${storyteller.whisperCppVersion} 0750 storyteller storyteller -"
          "C ${ghostStoryDir}/whisper-cpp/${storyteller.whisperCppVersion}/${storyteller.whisperVariant} 0750 storyteller storyteller - ${storyteller.whisperCpp}"
          "d ${ghostStoryDir}/models 0750 storyteller storyteller -"
          "C ${ghostStoryDir}/models/ggml-${storyteller.whisperModel}.bin 0640 storyteller storyteller - ${storyteller.whisperModelFile}"
        ];

        systemd.services.storyteller = {
          description = "Storyteller ebook/audiobook platform";
          after = [
            "network.target"
            "systemd-tmpfiles-setup.service"
          ];
          wants = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          environment = {
            HOME = homeDir;
            PORT = port';
            HOSTNAME = "127.0.0.1";
            STORYTELLER_DATA_DIR = dataDir;
            READIUM_PORT = toString readiumPort;
            ENABLE_WEB_READER = "true";
            STORYTELLER_WHISPER_VARIANT = storyteller.whisperVariant;
            STORYTELLER_SECRET_KEY_FILE = config.age.secrets.storyteller-secret-key.path;
          };

          serviceConfig = {
            Type = "simple";
            User = "storyteller";
            Group = "storyteller";
            ExecStart = lib.getExe storyteller;
            Restart = "on-failure";
            RestartSec = "5s";
            RequiresMountsFor = [ dataDir ];

            # Defense in depth; Storyteller only needs to write under STORYTELLER_DATA_DIR, its
            # HOME (ghost-story's whisper/model cache), and its own Next.js cache dir.
            ProtectSystem = "strict";
            ReadWritePaths = [ dataDir ];
            PrivateTmp = true;
          };
        };
      };
  };
}
