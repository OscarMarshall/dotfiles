{
  den,
  inputs,
  my,
  ...
}:
{
  flake-file.inputs.claude-code-nix = {
    inputs.nixpkgs.follows = "nixpkgs";
    url = "github:sadjow/claude-code-nix";
  };

  my.claude = {
    darwin.homebrew.casks = [ "claude" ];
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        gh
        nodejs
        python3
        uv
        jq
      ];

      programs.claude-code = {
        enable = true;
        enableMcpIntegration = true;
        package = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
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
    includes = [
      (den._.unfree [ "claude-code" ])
      my.mcp-servers
    ];
  };
}
