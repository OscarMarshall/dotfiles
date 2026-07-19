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
        context7.command = "${pkgs.context7-mcp}/bin/context7-mcp";
        # `programs.mcp`'s env.*.file support single-quotes the path before
        # `cat`-ing it, but agenix's Darwin secret paths are themselves an
        # unexpanded `$(getconf DARWIN_USER_TEMP_DIR)/agenix/...` shell
        # command substitution — single-quoting prevents that expansion, so
        # the token file is never found. Read it ourselves in a wrapper
        # script instead, where the substitution is left unquoted for bash
        # to expand at runtime.
        github.command = "${pkgs.writeShellScript "github-mcp-server-wrapper" ''
          export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.age.secrets.github-mcp-server-github-access-token.path})"
          exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio
        ''}";
        nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
    };
  };
}
