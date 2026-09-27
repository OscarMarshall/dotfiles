{ inputs, ... }: {
  my.pi.homeManager = _: {
    programs.pi-coding-agent = {
      enable = true;

      settings = {
        # Nix owns the package; an install-telemetry ping on a Nix-managed binary
        # is meaningless noise.
        enableInstallTelemetry = false;

        packages = [
          # Local path into the Nix store - same pinned commit as codex/opencode.
          "${inputs.ponytail}"
        ];
      };
    };
  };
}
