{
  den,
  lib,
  my,
  ...
}:
{
  den.aspects.oscar.provides.work =
    { host, ... }:
    {
      includes = lib.optionals (host.work or false) (
        builtins.attrValues den.aspects.oscar.provides.work.provides ++ (lib.optional (host.graphical or false) my.slack)
      );

      darwin.homebrew.casks = lib.optionals ((host.work or false) && (host.graphical or false)) [ "codex-app" ];

      homeManager =
        { pkgs, ... }:
        {
          home.packages = lib.optional (host.work or false) pkgs.codex;
        };
    };
}
