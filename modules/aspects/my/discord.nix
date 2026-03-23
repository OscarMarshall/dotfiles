{ den, lib, ... }:
{
  my.discord =
    { host, ... }:
    {
      includes = [ (den._.unfree [ "discord" ]) ];

      darwin.homebrew.casks = [ "discord" ];

      homeManager =
        { pkgs, ... }:
        {
          home.packages = with pkgs; lib.optionals (host != "darwin") [ discord ];
        };
    };
}
