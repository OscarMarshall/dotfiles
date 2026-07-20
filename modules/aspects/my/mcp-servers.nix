_: {
  # context7 is genuinely shared: it's plain doc lookup with no secrets, and
  # useful to every MCP-integrated program (Claude Code, Codex, ...). Servers
  # that are Claude-specific (or need a secret) live in `my.claude` instead,
  # under `programs.claude-code.mcpServers`.
  my.mcp-servers.homeManager = { pkgs, ... }: {
    programs.mcp = {
      enable = true;
      servers.context7.command = "${pkgs.context7-mcp}/bin/context7-mcp";
    };
  };
}
