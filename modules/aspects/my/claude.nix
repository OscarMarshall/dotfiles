{
  den,
  inputs,
  my,
  ...
}:
{
  flake-file.inputs.claude-code-nix = {
    url = "github:sadjow/claude-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.claude = {
    includes = [
      (den._.unfree [ "claude-code" ])
      my.mcp-servers
    ];

    darwin.homebrew.casks = [ "claude" ];

    homeManager = { config, pkgs, ... }: {
      age.secrets = {
        # Declared here (not in a top-level secrets block) so it lands in the
        # home-manager config's age.secrets, which is what config.age.secrets
        # refers to inside homeManager modules. The secrets block in user-level
        # aspects isn't forwarded to age.secrets per defaults.nix.
        github-mcp-server-github-access-token.rekeyFile = ../../../secrets/github-mcp-server-github-access-token.age;
        # Same generated secret netdata.nix's netdata-api vhost already produces
        # (secrets/generated/, not a hand-authored secrets/ primitive) - rekeyed here too so it
        # reaches every host running Claude Code, not just harmony.
        netdata-api-key.rekeyFile = ../../../secrets/generated/netdata-api-key.age;
      };

      home.packages = with pkgs; [
        gh
        jq
        nodejs
        python3
        uv
      ];

      programs.claude-code = {
        enable = true;

        # Wraps the real binary (rather than using `settings.env`, which has no secret-file
        # indirection - `programs.claude-code.settings` is plain freeform JSON, so any value there
        # is baked into the Nix store in plaintext) to give every Claude Code session, including
        # its own Bash tool calls, $NETDATA_API_KEY for the netdata-api vhost (nginx.nix's
        # `basicAuthSecret`) without an interactive Authentik login.
        #
        # A plain `writeShellScriptBin "claude" ...` wrapper has no version metadata, and the
        # module uses `lib.getVersion cfg.package` to pick between its modern and "legacy"
        # `--plugin-dir` MCP/plugin wrapper strategies - losing that made it silently fall back to
        # the legacy one (surfaced as a build warning: "Strict-parser subcommands such as `claude
        # rc` may reject managed MCP, LSP, or plugin arguments"). `symlinkJoin` + `makeWrapper`
        # instead, with `version` re-attached explicitly, keeps the underlying package's version
        # visible to that check.
        package =
          let
            unwrapped = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
          in
          pkgs.symlinkJoin {
            name = "claude-${unwrapped.version}";
            nativeBuildInputs = [ pkgs.makeWrapper ];
            paths = [ unwrapped ];

            postBuild = ''
              wrapProgram $out/bin/claude \
                --run 'export NETDATA_API_KEY="$(cat ${config.age.secrets.netdata-api-key.path})"'
            '';
          }
          // {
            inherit (unwrapped) version;
          };

        enableMcpIntegration = true;

        # Claude-specific MCP servers (as opposed to `my.mcp-servers`, which
        # holds servers shared with other MCP-integrated programs like Codex).
        mcpServers = {
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

        settings = {
          agentPushNotifEnabled = true;
          autoUpdaterStatus = "disabled";
          enableWorkflows = true;
          inputNeededNotifEnabled = true;

          permissions.allow = [
            "Bash(git:*)"
            "Bash(nix:*)"
          ];
        };
      };
    };
  };
}
