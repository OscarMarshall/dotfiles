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
    # Trips once nixpkgs' own mcp-nixos evaluates again (the broken-package refusal is a `throw`, so
    # tryEval catches it), signalling that the flake input above can be dropped.
    assertions = [
      {
        assertion = !(builtins.tryEval pkgs.mcp-nixos.drvPath).success;

        message = ''
          pkgs.mcp-nixos evaluates again: drop the `mcp-nixos` flake input in
          modules/aspects/my/mcp-servers.nix, switch my.claude and my.opencode back to
          `pkgs.mcp-nixos`, remove this assertion, and run `nix run .#write-flake`.
        '';
      }
    ];

    programs.mcp = {
      enable = true;
      servers.context7.command = "${pkgs.context7-mcp}/bin/context7-mcp";
    };
  };
}
