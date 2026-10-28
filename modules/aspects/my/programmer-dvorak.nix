{
  my.programmer-dvorak = {
    # xkeyboard-config's "us" layout, "dvp" variant is Programmer Dvorak. Listing it as a second
    # GNOME input source (rather than replacing "us") keeps English (US) the default and current
    # source; it just becomes selectable via the input source switcher.
    homeManager = { lib, ... }: {
      dconf.settings."org/gnome/desktop/input-sources" = {
        current = lib.hm.gvariant.mkUint32 0;

        sources = map lib.hm.gvariant.mkTuple [
          [
            "xkb"
            "us"
          ]
          [
            "xkb"
            "us+dvp"
          ]
        ];
      };
    };
  };
}
