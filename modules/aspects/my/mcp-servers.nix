{
  # mcp-nixos comes from its own flake rather than nixpkgs, and deliberately does *not* follow our
  # nixpkgs: nixpkgs-unstable moved python `mcp` to v2, which marks `fastmcp-slim` (and so
  # `pkgs.mcp-nixos`) broken. The flake's own locked nixpkgs still has a working fastmcp. Consumed
  # by `my.claude` and `my.opencode`, which both include this aspect.
  flake-file.inputs.mcp-nixos.url = "github:utensils/mcp-nixos";

  # context7 is genuinely shared: it's plain doc lookup with no secrets, and
  # useful to every MCP-integrated program (Claude Code, OpenCode, ...). Servers
  # that are Claude-specific (or need a secret) live in `my.claude` instead,
  # under `programs.claude-code.mcpServers`.
  my.mcp-servers.homeManager = { pkgs, ... }: {
    programs.mcp = {
      enable = true;
      servers.context7.command = "${pkgs.context7-mcp}/bin/context7-mcp";
    };
  };
}
