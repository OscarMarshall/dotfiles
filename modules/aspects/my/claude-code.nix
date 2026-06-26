{ inputs, ... }: {
  flake-file.inputs.claude-code-nix = {
    url = "github:sadjow/claude-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.claude-code = {
    secrets = _: {
      github-mcp-server-github-access-token.rekeyFile = ../../../secrets/github-mcp-server-github-access-token.age;
    };

    homeManager = { config, pkgs, ... }: {
      home.packages = with pkgs; [
        gh
        nodejs
        python3
        uv
        jq
      ];

      programs.claude-code = {
        enable = true;
        package = inputs.claude-code-nix.packages.${pkgs.system}.claude-code;

        settings = {
          autoUpdaterStatus = "disabled";
          permissions = {
            allow = [
              "Bash(git:*)"
              "Bash(nix:*)"
            ];
          };
        };

        mcpServers = {
          nixos = {
            type = "stdio";
            command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          };

          github = {
            type = "stdio";
            # MCP server configs are static JSON, so the token can't be
            # referenced directly — a wrapper reads the agenix path at launch.
            command = "${pkgs.writeShellScript "github-mcp-server-wrapper" ''
              export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.age.secrets.github-mcp-server-github-access-token.path})
              exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio
            ''}";
          };

          context7 = {
            type = "stdio";
            command = "${pkgs.context7-mcp}/bin/context7-mcp";
          };
        };
      };
    };
  };
}
