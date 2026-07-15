{ ... }: {
  my.mcp-servers.homeManager = { config, pkgs, ... }: {
    # Declared here (not in a top-level secrets block) so it lands in the
    # home-manager config's age.secrets, which is what config.age.secrets
    # refers to inside homeManager modules. The secrets block in user-level
    # aspects isn't forwarded to age.secrets per defaults.nix.
    age.secrets.github-mcp-server-github-access-token.rekeyFile = ../../../secrets/github-mcp-server-github-access-token.age;

    programs.mcp = {
      enable = true;

      servers = {
        nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";

        github = {
          command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
          args = [ "stdio" ];
          env.GITHUB_PERSONAL_ACCESS_TOKEN.file = config.age.secrets.github-mcp-server-github-access-token.path;
        };

        context7.command = "${pkgs.context7-mcp}/bin/context7-mcp";
      };
    };
  };
}
