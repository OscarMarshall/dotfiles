{
  lib,
  den,
  inputs,
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
        home.packages = lib.optional chatgpt pkgs.chatgpt;

        programs.codex = {
          enable = true;
          package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
          enableMcpIntegration = true;
        };
      };
    };
}
