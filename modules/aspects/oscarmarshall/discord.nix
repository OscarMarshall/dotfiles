{
  oscarmarshall.discord = {
    includes = [
      # (den._.unfree [ "discord" ])
    ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [ discord ];
      };
  };
}
