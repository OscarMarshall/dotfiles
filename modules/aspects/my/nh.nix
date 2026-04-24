{
  my.nh =
    { flake }:
    {
      homeManager.programs.nh = {
        enable = true;
        inherit flake;
        clean = {
          enable = true;
          extraArgs = "--keep-since 7d";
        };
      };
    };
}
