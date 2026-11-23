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
        githubToken = "github-mcp-server-github-access-token";
        readGithubToken =
          if useProtonPass then
            "PROTON_PASS_LINUX_KEYRING=${config.home.sessionVariables.PROTON_PASS_LINUX_KEYRING} ${lib.getExe' pkgs.proton-pass-cli "pass-cli"} item view 'pass://Personal/GitHub MCP Server/API Key'"
          else
            # Unquoted on purpose: agenix's Home Manager paths hold a literal `${XDG_RUNTIME_DIR}`.
            "cat ${config.age.secrets.${githubToken}.path}";
        # Same split as my.claude: headless hosts have no Secret Service for pass-cli's DB key, so
        # they read the agenix copy; the keyring provider is repeated inline because OpenCode isn't
        # always started from a shell.
        useProtonPass = host.graphical or false;
      in
      {
        # Identical to my.claude's definition; identical `rekeyFile` definitions merge cleanly.
        age.secrets = lib.mkIf (!useProtonPass) { ${githubToken}.rekeyFile = ../../../secrets/${githubToken}.age; };

        programs.opencode = {
          enable = true;
          # Picks up `my.mcp-servers`' shared servers (context7) from `programs.mcp`.
          enableMcpIntegration = true;

          settings = {
            # Nix owns the package; a self-update would write into ~/.opencode and shadow it.
            autoupdate = false;

            mcp = {
              # Wrapped for the same reason as my.claude's github MCP server: OpenCode's env
              # interpolation (`{env:...}`/`{file:...}`) can't run a command or expand the agenix path,
              # so a wrapper script reads the token instead.
              github = {
                command = [
                  "${pkgs.writeShellScript "opencode-github-mcp-server-wrapper" ''
                    export GITHUB_PERSONAL_ACCESS_TOKEN="$(${readGithubToken})"
                    exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio
                  ''}"
                ];

                type = "local";
              };

              nixos = {
                command = [ "${pkgs.mcp-nixos}/bin/mcp-nixos" ];
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
