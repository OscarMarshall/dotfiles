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

      homeManager =
        { pkgs, ... }:
        {
          home.packages = lib.optional (host.work or false) pkgs.codex;
        };
    };
}
