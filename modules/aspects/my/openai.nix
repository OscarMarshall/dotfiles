{ inputs, my, ... }: {
  flake-file.inputs.codex-cli-nix = {
    url = "github:sadjow/codex-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.openai = {
    includes = [
      my.mcp-servers
      my.ponytail
    ];

    homeManager = { pkgs, ... }: {
      programs.codex = {
        enable = true;
        package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
        enableMcpIntegration = true;
      };
    };
  };
}
