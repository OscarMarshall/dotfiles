{ my, ... }: {
  my.opencode = {
    includes = [ my.mcp-servers ];

    homeManager = { config, pkgs, ... }: {
      # Same primitive secret my.claude rekeys for its GitHub MCP server - declared again here so
      # OpenCode doesn't silently depend on my.claude also being included. Identical `rekeyFile`
      # definitions merge cleanly.
      age.secrets.github-mcp-server-github-access-token.rekeyFile = ../../../secrets/github-mcp-server-github-access-token.age;

      programs.opencode = {
        enable = true;
        # Picks up `my.mcp-servers`' shared servers (context7) from `programs.mcp`.
        enableMcpIntegration = true;

        settings = {
          # Nix owns the package; a self-update would write into ~/.opencode and shadow it.
          autoupdate = false;

          mcp = {
            # Wrapped for the same reason as my.claude's github MCP server: agenix's Darwin secret
            # path is an unexpanded `$(getconf DARWIN_USER_TEMP_DIR)/...` substitution, which
            # OpenCode's `{file:...}` env interpolation would take literally.
            github = {
              command = [
                "${pkgs.writeShellScript "opencode-github-mcp-server-wrapper" ''
                  export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.age.secrets.github-mcp-server-github-access-token.path})"
                  exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio
                ''}"
              ];

              type = "local";
            };

            nixos = {
              command = [ "${pkgs.mcp-nixos}/bin/mcp-nixos" ];
              type = "local";
            };
          };
        };
      };
    };
  };
}
