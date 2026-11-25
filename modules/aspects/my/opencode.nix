{
  lib,
  inputs,
  my,
  ...
}:
{
  my.opencode = { host, user, ... }: {
    includes = [
      my.mcp-servers
      my.proton-pass
    ];

    homeManager =
      { config, pkgs, ... }:
      let
        # Same as my.claude: headless hosts have no Secret Service for pass-cli's DB key, so they get
        # no GitHub MCP server.
        useProtonPass = host.graphical or false;
      in
      {
        programs.opencode = {
          enable = true;
          # Picks up `my.mcp-servers`' shared servers (context7) from `programs.mcp`.
          enableMcpIntegration = true;

          settings = {
            # Nix owns the package; a self-update would write into ~/.opencode and shadow it.
            autoupdate = false;

            mcp = {
              nixos = {
                command = [ "${pkgs.mcp-nixos}/bin/mcp-nixos" ];
                type = "local";
              };
            }
            // lib.optionalAttrs useProtonPass {
              # Wrapped for the same reason as my.claude's github MCP server: OpenCode's env
              # interpolation (`{env:...}`/`{file:...}`) can't run a command, so a wrapper script
              # looks the token up. The keyring provider is repeated inline because OpenCode isn't
              # always started from a shell.
              github = {
                command = [
                  "${pkgs.writeShellScript "opencode-github-mcp-server-wrapper" ''
                    export GITHUB_PERSONAL_ACCESS_TOKEN="$(PROTON_PASS_LINUX_KEYRING=${config.home.sessionVariables.PROTON_PASS_LINUX_KEYRING} ${lib.getExe' pkgs.proton-pass-cli "pass-cli"} item view 'pass://Personal/GitHub MCP Server/API Key')"
                    exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio
                  ''}"
                ];

                type = "local";
              };
            };

            plugin = [ inputs.ponytail ];
          };
        };
      };

    # `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [
      ".local/share/opencode" # provider auth (auth.json), sessions, snapshots
      ".local/state/opencode" # prompt history, recent models
    ];
  };
}
