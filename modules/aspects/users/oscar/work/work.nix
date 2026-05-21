{
  den,
  lib,
  my,
  ...
}:
let
  contextAttrs =
    context:
    if (context ? host) && context.host != null then
      context.host
    else if (context ? home) && context.home != null then
      context.home
    else if
      (context ? system)
      && (context ? userName)
      && (context ? hostName)
      && context.hostName != null
      && builtins.hasAttr context.system den.homes
      && builtins.hasAttr "${context.userName}@${context.hostName}" den.homes.${context.system}
    then
      den.homes.${context.system}."${context.userName}@${context.hostName}"
    else
      { };
  contextFlag = context: flag: (contextAttrs context).${flag} or false;
in
{
  den.aspects.oscar.provides.work = context: {
    includes = lib.optionals (contextFlag context "work") (
      builtins.attrValues den.aspects.oscar.provides.work.provides
      ++ (lib.optional (contextFlag context "graphical") my.slack)
    );

    homeManager =
      { pkgs, ... }:
      {
        home.packages = lib.optional (contextFlag context "work") pkgs.codex;
      };
  };
}
