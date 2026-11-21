{ inputs, my, ... }: {
  my.opencode = { user, ... }: {
    includes = [
      my.mcp-servers
      my.proton-pass
    ];

    homeManager = { pkgs, ... }: {
      programs.opencode = {
        enable = true;
        # Picks up `my.mcp-servers`' shared servers (context7) from `programs.mcp`.
        enableMcpIntegration = true;

        settings = {
          # Nix owns the package; a self-update would write into ~/.opencode and shadow it.
          autoupdate = false;

          mcp = {
            # Wrapped for the same reason as my.claude's github MCP server: OpenCode's env
            # interpolation (`{env:...}`/`{file:...}`) can't run a command, so the token is looked up
            # in Proton Pass by a wrapper script instead.
            github = {
              command = [
                "${pkgs.writeShellScript "opencode-github-mcp-server-wrapper" ''
                  export GITHUB_PERSONAL_ACCESS_TOKEN="$(pass-cli item view 'pass://Personal/GitHub MCP Server/API Key')"
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

          plugin = [ inputs.ponytail ];
        };
      };
    };

    # `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [
      ".local/share/opencode" # provider auth (auth.json), sessions, snapshots
      ".local/state/opencode" # prompt history, recent models
    ];
  };
}
