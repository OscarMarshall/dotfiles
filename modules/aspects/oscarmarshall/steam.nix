{ den, ... }:
{
  oscarmarshall.steam = {
    includes = [
      (den._.unfree [
        "steam"
        "steam-unwrapped"
      ])
    ];

    darwin.homebrew.casks = [ "steam" ];
    nixos.programs.steam.enable = true;
  };
}
