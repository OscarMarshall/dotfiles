{
  den,
  inputs,
  lib,
  my,
  ...
}:
{
  flake-file.inputs.codex-cli-nix = {
    inputs.nixpkgs.follows = "nixpkgs";
    url = "github:sadjow/codex-cli-nix";
  };

  my.openai =
    {
      chatgpt ? false,
    }:
    {
      homeManager = { pkgs, ... }: {
        home.packages = lib.optional chatgpt pkgs.chatgpt;
        programs.codex = {
          enable = true;
          enableMcpIntegration = true;
          package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
        };
      };
      includes = [ my.mcp-servers ] ++ lib.optional chatgpt (den._.unfree [ "chatgpt" ]);
    };
}
