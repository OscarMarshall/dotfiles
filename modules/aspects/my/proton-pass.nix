{ den, ... }:
{
  my.proton-pass = {
    includes = [ (den._.unfree [ "proton-pass-cli" ]) ];

    homeManager.services.proton-pass-agent.enable = true;
  };
}
