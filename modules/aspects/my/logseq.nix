{ inputs, ... }:

{
  den.quirks.logseq-graphs = {
    description = "Logseq graph server definitions, each { name [, rootDir] }";
  };

  flake-file.inputs.nix-logseq-git-flake = {
    url = "github:Bad3r/nix-logseq-git-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.logseq =
    { cli-only ? false, ... }:
    {
      homeManager = { pkgs, lib, ... }: {
        home.packages =
          [ inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli ]
          ++ lib.optional (!cli-only) inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq;
      };

      os = { ... }: {
        nix.settings = {
          extra-substituters = [ "https://nix-logseq-git-flake.cachix.org" ];
          extra-trusted-public-keys = [ "nix-logseq-git-flake.cachix.org-1:DSBNW07PSRyCvS926tpIWahb53OIydwwZhsP6LhJNZo=" ];
        };
      };

      hmLinux =
        { pkgs, lib, logseq-graphs, ... }:
        let
          cliExe = "${inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli}/bin/logseq-cli";
          serverStart = graph:
            "${cliExe} server start --graph ${graph.name}"
            + (if graph ? rootDir then " --root-dir ${graph.rootDir}" else "");
          serverStop = graph: "${cliExe} server stop --graph ${graph.name}";
        in
        lib.mkIf (logseq-graphs != [ ]) {
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
            }) logseq-graphs
          );
        };

      hmDarwin =
        { pkgs, lib, logseq-graphs, ... }:
        let
          cliExe = "${inputs.nix-logseq-git-flake.packages.${pkgs.system}.logseq-cli}/bin/logseq-cli";
          serverStart = graph:
            "${cliExe} server start --graph ${graph.name}"
            + (if graph ? rootDir then " --root-dir ${graph.rootDir}" else "");
        in
        lib.mkIf (logseq-graphs != [ ]) {
          launchd.agents = lib.listToAttrs (
            map (graph: {
              name = "logseq-graph-${graph.name}";
              value = {
                enable = true;
                config = {
                  Label = "com.logseq.graph.${graph.name}";
                  ProgramArguments = [ "/bin/sh" "-c" "exec ${serverStart graph}" ];
                  RunAtLoad = true;
                  KeepAlive.Crashed = true;
                  ThrottleInterval = 30;
                  StandardOutPath = "/tmp/logseq-graph-${graph.name}.log";
                  StandardErrorPath = "/tmp/logseq-graph-${graph.name}.log";
                };
              };
            }) logseq-graphs
          );
        };
    };
}
