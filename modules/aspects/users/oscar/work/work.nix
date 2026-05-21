{
  den,
  lib,
  my,
  ...
}:
let
  scopeFromArgs =
    {
      host ? null,
      home ? null,
      ...
    }@args:
    if host != null then
      host
    else if home != null then
      home
    else
      args;
in
{
  den.aspects.oscar.provides.work =
    args:
    let
      scope = scopeFromArgs args;
    in
    {
      includes = lib.optionals (scope.work or false) (
        builtins.attrValues den.aspects.oscar.provides.work.provides ++ (lib.optional (scope.graphical or false) my.slack)
      );

      homeManager =
        { pkgs, ... }:
        {
          home.packages = lib.optional (scope.work or false) pkgs.codex;
        };
    };
}
