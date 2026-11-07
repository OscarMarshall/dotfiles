{ inputs, my, ... }: {
  my.opencode = { user, ... }: {
    includes = [ my.mcp-servers ];

    homeManager = { config, pkgs, ... }: {
      # Same primitive secret my.claude rekeys for its GitHub MCP server - declared again here so
      # OpenCode doesn't silently depend on my.claude also being included. Identical `rekeyFile`
      # definitions merge cleanly.
      age.secrets.github-mcp-server-github-access-token.rekeyFile = ../../../secrets/github-mcp-server-github-access-token.age;

      programs.opencode = {
        enable = true;

        # nixpkgs' opencode 2.2.5 shipped one node_modules hash for every platform, but the output
        # differs on Linux, so it fails to build. Fixed upstream in NixOS/nixpkgs#582675 (not yet in
        # nixpkgs-unstable as of 2026-11-06); borrow its Linux hash until it lands, then drop this.
        package = pkgs.opencode.overrideAttrs (
          old:
          assert
            old.node_modules.outputHash == "sha256-xfOVcw1+waLVNhFDwzOtzxrUSQEogvn88YomydOlhwc="
            || throw "opencode.nix: pkgs.opencode's node_modules hash changed - NixOS/nixpkgs#582675 has likely landed; drop the node_modules override.";
          {
            node_modules = old.node_modules.overrideAttrs { outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA="; };
          }
        );

        # Picks up `my.mcp-servers`' shared servers (context7) from `programs.mcp`.
        enableMcpIntegration = true;

        settings = {
          # Nix owns the package; a self-update would write into ~/.opencode and shadow it.
          autoupdate = false;

          mcp = {
            # Wrapped for the same reason as my.claude's github MCP server: agenix's Home Manager
            # secret path is an unexpanded `${XDG_RUNTIME_DIR}/...`, which OpenCode's `{file:...}`
            # env interpolation would take literally.
            github = {
              command = [
                "${pkgs.writeShellScript "opencode-github-mcp-server-wrapper" ''
                  export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.age.secrets.github-mcp-server-github-access-token.path})"
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
