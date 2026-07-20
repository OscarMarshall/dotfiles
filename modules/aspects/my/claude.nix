{
  den,
  inputs,
  my,
  ...
}:
{
  flake-file.inputs.claude-code-nix = {
    url = "github:sadjow/claude-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.claude = {
    includes = [
      (den._.unfree [ "claude-code" ])
      my.mcp-servers
    ];

    darwin.homebrew.casks = [ "claude" ];

    homeManager = { config, pkgs, ... }: {
      age = {
        secrets = {
          # Declared here (not in a top-level secrets block) so it lands in the
          # home-manager config's age.secrets, which is what config.age.secrets
          # refers to inside homeManager modules. The secrets block in user-level
          # aspects isn't forwarded to age.secrets per defaults.nix.
          github-mcp-server-github-access-token.rekeyFile = ../../../secrets/github-mcp-server-github-access-token.age;
          netdata-cloud-mcp-token.rekeyFile = ../../../secrets/netdata-cloud-mcp-token.age;
        };
      };

      home.packages = with pkgs; [
        gh
        jq
        nodejs
        python3
        uv
      ];

      programs.claude-code = {
        enable = true;
        package = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
        enableMcpIntegration = true;

        # Claude-specific MCP servers (as opposed to `my.mcp-servers`, which
        # holds servers shared with other MCP-integrated programs like Codex).
        mcpServers = {
          # `programs.mcp`'s env.*.file support single-quotes the path before
          # `cat`-ing it, but agenix's Darwin secret paths are themselves an
          # unexpanded `$(getconf DARWIN_USER_TEMP_DIR)/agenix/...` shell
          # command substitution — single-quoting prevents that expansion, so
          # the token file is never found. Read it ourselves in a wrapper
          # script instead, where the substitution is left unquoted for bash
          # to expand at runtime.
          github.command = "${pkgs.writeShellScript "github-mcp-server-wrapper" ''
            export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.age.secrets.github-mcp-server-github-access-token.path})"
            exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio
          ''}";

          # Netdata Cloud's MCP server is remote (streamable HTTP) with no
          # `command`/`env` secret-file support in `programs.claude-code.mcpServers`
          # for remote servers, so we bridge it through mcp-proxy as a local
          # stdio server instead — same secret-at-runtime pattern as `github` above.
          netdata-cloud.command = "${pkgs.writeShellScript "netdata-cloud-mcp-wrapper" ''
            exec ${pkgs.mcp-proxy}/bin/mcp-proxy https://app.netdata.cloud/api/v1/mcp \
              --transport streamablehttp \
              -H Authorization "Bearer $(cat ${config.age.secrets.netdata-cloud-mcp-token.path})"
          ''}";

          nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        };

        settings = {
          agentPushNotifEnabled = true;
          autoUpdaterStatus = "disabled";
          enableWorkflows = true;
          inputNeededNotifEnabled = true;

          permissions = {
            allow = [
              "Bash(git:*)"
              "Bash(nix:*)"
            ];
          };
        };
      };
    };
  };
}
