{ my, ... }:
{
  den.aspects.oscar._.work._.slack = my.host-flag "graphical" { includes = [ my.slack ]; };
}
