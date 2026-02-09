{ den, lib, ... }:
{
  oscarmarshall.host-flag =
    flag: aspects:
    let
      aspect = den.lib.parametric { includes = aspects; };
    in
    den.lib.parametric {
      includes = [
        (
          context@{ host, ... }:
          {
            includes = lib.optionals host.${flag} or false [
              (den.lib.statics aspect)
              (aspect context)
            ];
          }
        )
        (
          context@{ home, ... }:
          {
            includes = lib.optionals home.${flag} or false [
              (den.lib.statics aspect)
              (aspect context)
            ];
          }
        )
      ];
    };
}
