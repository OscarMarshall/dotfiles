{ den, ... }:
{
  oscarmarshall.steam = {
    includes = [ (den._.unfree [ "steam" ]) ];
    darwin.homebrew.casks = [ "steam" ];
    nixos.programs.steam.enable = true;
  };
}
