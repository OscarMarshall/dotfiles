{ inputs, ... }: {
  flake-file.inputs.nix-logseq-git-flake = {
    url = "github:Bad3r/nix-logseq-git-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.logseq =
    {
      cli-only ? false,
      graphs ? [ ],
      ...
    }:
    {
      homeManager =
        { pkgs, lib, ... }:
        let
          cliExe = "${inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli}/bin/logseq-cli";
          serverStart =
            graph:
            "${cliExe} server start --graph ${lib.escapeShellArg graph.name}"
            + (if graph ? rootDir && graph.rootDir != null then " --root-dir ${lib.escapeShellArg graph.rootDir}" else "");
          serverStop = graph: "${cliExe} server stop --graph ${lib.escapeShellArg graph.name}";
        in
        lib.mkMerge [
          {
            home.packages = [
              inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli
            ]
            ++ lib.optional (!cli-only) inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq;
          }
          (lib.mkIf (graphs != [ ] && pkgs.stdenv.isLinux) {
            systemd.user.services = lib.listToAttrs (
              map (graph: {
                name = "logseq-graph-${graph.name}";
                value = {
                  Unit.Description = "Logseq graph server for ${graph.name}";
                  Service = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    ExecStart = serverStart graph;
                    ExecStop = serverStop graph;
                  };
                  Install.WantedBy = [ "default.target" ];
                };
              }) graphs
            );
          })
          (lib.mkIf (graphs != [ ] && pkgs.stdenv.isDarwin) {
            launchd.agents = lib.listToAttrs (
              map (graph: {
                name = "logseq-graph-${graph.name}";
                value = {
                  enable = true;
                  config = {
                    Label = "com.logseq.graph.${graph.name}";
                    ProgramArguments = [
                      "/bin/sh"
                      "-c"
                      "exec ${serverStart graph}"
                    ];
                    RunAtLoad = true;
                    KeepAlive.Crashed = true;
                    ThrottleInterval = 30;
                    StandardOutPath = "/tmp/logseq-graph-${graph.name}.log";
                    StandardErrorPath = "/tmp/logseq-graph-${graph.name}.log";
                  };
                };
              }) graphs
            );
          })
        ];

      substituters = [
        {
          substituter = "https://nix-logseq-git-flake.cachix.org";
          publicKey = "nix-logseq-git-flake.cachix.org-1:DSBNW07PSRyCvS926tpIWahb53OIydwwZhsP6LhJNZo=";
        }
      ];
    };
}
