{ den, my, ... }:
{
  den.aspects.oscar.provides.work = den.lib.parametric {
    includes = [ (my.host-flag "work" { includes = builtins.attrValues den.aspects.oscar._.work._; }) ];
  };
}
