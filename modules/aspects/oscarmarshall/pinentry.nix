{ lib, ... }:
{
  oscarmarshall.pinentry =
    { HM-OS-USER }:
    {
      homeManager =
        { pkgs, ... }:
        {
          home.packages =
            with pkgs;
            (lib.optionals (HM-OS-USER.host.class != "darwin") [ pinentry-all ])
            ++ (lib.optionals (HM-OS-USER.host.class == "darwin") [ pinentry_mac ]);
        };
    };
}
