{
  my.colima.hmDarwin = { pkgs, ... }: {
    # docker-compose (the Go-based Compose V2) supplies the standalone `docker-compose` binary
    # that Dashboard's `script/spring` still shells out to. `docker compose` (the subcommand)
    # needs no separate wiring - nixpkgs' `docker` bundles it (and buildx) as CLI plugins by
    # default (`composeSupport`/`buildxSupport` in nixpkgs' docker derivation).
    home.packages = [
      pkgs.docker
      pkgs.docker-compose
    ];

    programs.docker-cli.enable = true;

    services.colima = {
      enable = true;

      # `isService` runs colima as a per-user LaunchAgent (RunAtLoad + KeepAlive), so it's up
      # after login without a manual `colima start` and without re-running on every
      # nix-darwin/home-manager activation - only when the generated LaunchAgent plist actually
      # changes. `isActive`/`setDockerHost` make this profile's context the one Docker resolves
      # by default (every host also gets GUI-launched processes onto this same PATH - see the
      # `guiPath` default in modules/aspects/defaults.nix).
      profiles.default = {
        isActive = true;
        isService = true;
        setDockerHost = true;

        settings = {
          cpu = 6;
          disk = 100;
          memory = 6;
          mountType = "virtiofs";
          rosetta = true;
          runtime = "docker";
          vmType = "vz";
        };
      };
    };
  };
}
