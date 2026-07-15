{
  den,
  inputs,
  lib,
  my,
  ...
}:
{
  flake-file.inputs.codex-cli-nix = {
    url = "github:sadjow/codex-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.openai =
    {
      chatgpt ? false,
    }:
    {
      includes = [ my.mcp-servers ] ++ lib.optional chatgpt (den._.unfree [ "chatgpt" ]);

      homeManager = { pkgs, ... }: {
        programs.codex = {
          enable = true;
          package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
          enableMcpIntegration = true;

          settings = {
            model = "gpt-5.6-sol";
            model_reasoning_effort = "medium";
            approvals_reviewer = "auto_review";

            mcp_servers.outlook = {
              command = "uv";
              args = [
                "--directory"
                "/Users/oscar/co/outlook-mcp-server"
                "run"
                "outlook-mcp"
              ];
              env = {
                OUTLOOK_MCP_CONFIG_DIR = "/Users/oscar/.config/outlook/mcp/sessions";
                OUTLOOK_MCP_ENABLE_WRITE_TOOLS = "true";
              };
            };
          };
        };

        home.packages = lib.optional chatgpt pkgs.chatgpt;
      };
    };
}
