{
  my.programmer-dvorak = {
    # macOS ships plain Dvorak but not Programmer Dvorak. Upstream publishes it only as a
    # Homebrew cask (https://formulae.brew.sh/cask/programmer-dvorak), but that cask's
    # `container nested:` pkg archive isn't extracted correctly by `brew install`/`brew bundle`
    # as of Homebrew 6.0.10 (https://github.com/Homebrew/brew/issues/23094), which always
    # leaves the bundle missing. So the same upstream .pkg.zip is unpacked here with Nix instead
    # and copied into place system-wide (rather than per-user), which is also a commonly cited
    # workaround for third-party keyboard layout flakiness with sandboxed apps like Safari.
    darwin =
      { pkgs, ... }:
      let
        bundle =
          pkgs.runCommand "programmer-dvorak-bundle"
            {
              nativeBuildInputs = [
                pkgs.unzip
                pkgs.libarchive
              ];
            }
            ''
              unzip -q ${
                pkgs.fetchurl {
                  url = "https://www.kaufmann.no/downloads/macos/ProgrammerDvorak-1_2_13.pkg.zip";
                  sha256 = "sha256-hC/69xSqrJGwKHxORXbxi+G/wyaTcJWToRhXKnzHgAY=";
                }
              } -d extracted
              mkdir -p $out
              bsdtar -xf "extracted/Programmer Dvorak v1.2.pkg/Contents/Archive.pax.gz" -C $out
            '';
      in
      {
        # macOS caches the list of installed keyboard layouts (com.apple.IntlDataCache.le*) and
        # only rescans it at boot, so a newly (un)installed .bundle won't show up in System
        # Settings -> Keyboard -> Input Sources until the cache is cleared and the machine is
        # rebooted.
        system.activationScripts.postActivation.text = ''
          rm -f /System/Library/Caches/com.apple.IntlDataCache.le*
          rm -f /private/var/folders/*/*/C/com.apple.IntlDataCache.le*

          if ! diff -rq "${bundle}/Library/Keyboard Layouts/Programmer Dvorak.bundle" "/Library/Keyboard Layouts/Programmer Dvorak.bundle" >/dev/null 2>&1; then
            rm -rf "/Library/Keyboard Layouts/Programmer Dvorak.bundle"
            cp -R "${bundle}/Library/Keyboard Layouts/Programmer Dvorak.bundle" "/Library/Keyboard Layouts/Programmer Dvorak.bundle"
          fi
        '';
      };

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
