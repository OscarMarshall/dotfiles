{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  # Only apply on darwin systems
  config = lib.mkIf pkgs.stdenv.isDarwin {
    system = {
      # Set Git commit hash for darwin-version.
      configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      stateVersion = lib.mkIf (config.networking.hostName == "omarshal-m-2fd2") 5;

      activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = ["/Applications"];
        };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';
    };

    nixpkgs = {
      hostPlatform = lib.mkIf (config.networking.hostName == "omarshal-m-2fd2") "aarch64-darwin";
    };

    # Time zone for darwin systems
    time.timeZone = lib.mkDefault "America/Los_Angeles";

    # Nix settings for darwin
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
