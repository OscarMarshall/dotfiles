{ den, lib, ... }:
{
  oscarmarshall.host-flag =
    flag: aspect:
    let
      parametric-aspect = den.lib.parametric (aspect // (if (!aspect ? includes) then { includes = [ ]; } else { }));
    in
    den.lib.parametric {
      includes = [
        (
          context@{ host, ... }:
          {
            includes = lib.optionals host.${flag} or false [
              (den.lib.owned parametric-aspect)
              (den.lib.statics parametric-aspect)
              (parametric-aspect context)
            ];
          }
        )
        (
          context@{ home, ... }:
          {
            includes = lib.optionals home.${flag} or false [
              (den.lib.owned parametric-aspect)
              (den.lib.statics parametric-aspect)
              (parametric-aspect context)
            ];
          }
        )
      ];
    };
}
