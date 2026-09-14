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
        # Same generated secrets beszel.nix's beszel-api vhost and hub admin account already
        # produce (secrets/generated/, not a hand-authored secrets/ primitive) - rekeyed here too
        # so they reach every host running Claude Code, not just harmony.
        beszel-admin-password.rekeyFile = ../../../secrets/generated/beszel-admin-password.age;
        beszel-api-key.rekeyFile = ../../../secrets/generated/beszel-api-key.age;
        # Declared here (not in a top-level secrets block) so it lands in the
        # home-manager config's age.secrets, which is what config.age.secrets
        # refers to inside homeManager modules. The secrets block in user-level
        # aspects isn't forwarded to age.secrets per defaults.nix.
        github-mcp-server-github-access-token.rekeyFile = ../../../secrets/github-mcp-server-github-access-token.age;
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
        # its own Bash tool calls, credentials for the beszel-api vhost (nginx.nix's
        # `basicAuthSecret`) without an interactive Authentik login. Unlike Netdata (no auth of
        # its own), Beszel's hub needs a real login on top of that vhost's Basic Auth gate -
        # $BESZEL_API_KEY is the Basic Auth password, $BESZEL_ADMIN_PASSWORD is the actual hub
        # account's password (email is the fixed, non-secret `admin@beszel.local` from
        # beszel.nix - safe to hardcode, it's never a real mailbox).
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
                --run 'export BESZEL_API_KEY="$(cat ${config.age.secrets.beszel-api-key.path})"' \
                --run 'export BESZEL_ADMIN_PASSWORD="$(cat ${config.age.secrets.beszel-admin-password.path})"'
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
