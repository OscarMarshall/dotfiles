{ inputs, ... }: {
  my.pi.homeManager = _: {
    programs.pi-coding-agent = {
      enable = true;

      # home-manager links ~/.pi/agent/settings.json read-only into the Nix store, so Pi's own
      # writes to it fail: `/model` and `/thinking` still switch the current session, but Ctrl+S
      # can't persist a new default and `/settings` changes last only until exit. Every default
      # worth keeping therefore lives here.
      settings = {
        defaultModel = "claude-opus-5-5";
        defaultProvider = "anthropic";
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
