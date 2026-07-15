{ my, ... }: {
  den.aspects.OMARSHAL-M-T2QF = {
    includes = with my; [ homebrew ];

    darwin = {
      age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJYml5zuvVCI6yKyiCz9Jx5wv9S4OrzZRltqzEH1NQdC";

      # Used for backwards compatibility, please read the changelog before changing.
      #
      # $ darwin-rebuild changelog
      system.stateVersion = 7;
    };

    provides.oscar = {
      homeManager = { config, pkgs, ... }: {
        # This value determines the Home Manager release that your configuration is compatible with. This helps
        # avoid breakage when a new Home Manager release introduces backwards incompatible changes.
        #
        # You can update Home Manager without changing this value. See the Home Manager release notes for a list
        # of state version changes in each release.
        home.stateVersion = "26.11";

        # fish defaults this to true for apropos completion, but it has no effect since
        # programs.man.package is null on Darwin (macOS's own man is used instead).
        programs.man.generateCaches = false;

        programs.codex.settings = {
          model = "gpt-5.6-sol";
          model_reasoning_effort = "medium";
          approvals_reviewer = "auto_review";

          # Only checked out on this machine.
          mcp_servers.outlook = {
            command = "${pkgs.uv}/bin/uv";
            args = [
              "--directory"
              "${config.home.homeDirectory}/co/outlook-mcp-server"
              "run"
              "outlook-mcp"
            ];
            env = {
              OUTLOOK_MCP_CONFIG_DIR = "${config.xdg.configHome}/outlook/mcp/sessions";
              OUTLOOK_MCP_ENABLE_WRITE_TOOLS = "true";
            };
          };
        };
      };

      # Den's allHomeNodes spawn re-walks the host aspect without the user's own includes, so none of the
      # hmXxx keys are present at compile time. Without them, the hmXxx→homeManager forwards compiled by
      # hmPlatforms become Tier 2 (complex) routes that call resolveSourceFallback, which creates a
      # self-parent inner spawn and throws. Sentinel empty modules here make each key present so the
      # forwards compile as Tier 1 (simple) routes instead.
      hmLinux = { };
      hmDarwin = { };
      hmAarch64 = { };
      hm64bit = { };
    };
  };
}
