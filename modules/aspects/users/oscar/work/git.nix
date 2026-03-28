{ lib, ... }:
{
  den.aspects.oscar.provides.work.provides.git.homeManager.programs.git.settings.user.email =
    lib.mkForce "omarshal@meraki.com";
}
