{
  my.programmer-dvorak = {
    # macOS caches the list of installed keyboard layouts (com.apple.IntlDataCache.le*) and only
    # rescans it at boot, so a newly (un)installed .bundle won't show up in System Settings ->
    # Keyboard -> Input Sources until the cache is cleared and the machine is rebooted.
    darwin.system.activationScripts.postActivation.text = ''
      rm -f /System/Library/Caches/com.apple.IntlDataCache.le*
      rm -f /private/var/folders/*/*/C/com.apple.IntlDataCache.le*
    '';

    # macOS ships plain Dvorak but not Programmer Dvorak, so it's installed via the Homebrew cask
    # (https://formulae.brew.sh/cask/programmer-dvorak), which places the bundle in the
    # system-wide /Library/Keyboard Layouts rather than per-user.
    darwin.homebrew.casks = [ "programmer-dvorak" ];

    # xkeyboard-config's "us" layout, "dvp" variant is Programmer Dvorak. Listing it as a second
    # GNOME input source (rather than replacing "us") keeps English (US) the default and current
    # source; it just becomes selectable via the input source switcher.
    hmLinux = { lib, ... }: {
      dconf.settings."org/gnome/desktop/input-sources" = {
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
        current = lib.hm.gvariant.mkUint32 0;
      };
    };
  };
}
