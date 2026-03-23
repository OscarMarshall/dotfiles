{ den, my, ... }:
{
  den.aspects.oscar.provides.work = {
    includes = [
      (my.host-flag "work" {
        includes = builtins.attrValues den.aspects.oscar.provides.work.provides ++ [
          (my.host-flag "graphical" { includes = [ my.slack ]; })
        ];

        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [ codex ];
          };
      })
    ];
  };
}
