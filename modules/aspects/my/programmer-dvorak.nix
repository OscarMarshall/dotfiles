{
  my.programmer-dvorak = {
    # macOS ships plain Dvorak but not Programmer Dvorak, so the layout is fetched from
    # https://www.kaufmann.no/roland/dvorak/ (the same author as xkeyboard-config's "dvp" variant)
    # and installed per-user rather than system-wide, so it never becomes the default for other
    # accounts on the machine.
    hmDarwin =
      { pkgs, ... }:
      let
        src = pkgs.fetchurl {
          url = "https://www.kaufmann.no/downloads/macos/ProgrammerDvorak-1_2_13.src.zip";
          hash = "sha256-k0sFa2oV6/NEujfr08Qc6KPPlNbL7yyeRQW/WOrkcuA=";
        };
        keylayout = pkgs.runCommand "programmer-dvorak.keylayout" { nativeBuildInputs = [ pkgs.unzip ]; } ''
          unzip -p ${src} "Programmer Dvorak.keylayout" > $out
        '';
      in
      {
        home.file = {
          "Library/Keyboard Layouts/Programmer Dvorak.bundle/Contents/Info.plist".text = ''
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            <key>CFBundleIdentifier</key><string>com.apple.keyboardlayout.Programmer Dvorak</string>
            <key>CFBundleName</key><string>Programmer Dvorak</string>
            <key>CFBundleVersion</key><string>1.2</string>
            <key>KLInfo_Programmer Dvorak</key>
              <dict>
              <key>TISInputSourceID</key><string>com.apple.keyboardlayout.Programmer Dvorak</string>
              <key>TISIntendedLanguage</key><string>en-Latn</string>
              </dict>
            </dict>
            </plist>
          '';

          "Library/Keyboard Layouts/Programmer Dvorak.bundle/Contents/version.plist".text = ''
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            <key>BuildVersion</key><string>1.2</string>
            <key>CFBundleVersion</key><string>1.2</string>
            <key>ProjectName</key><string>Programmer Dvorak</string>
            <key>SourceVersion</key><string>1.2</string>
            </dict>
            </plist>
          '';

          "Library/Keyboard Layouts/Programmer Dvorak.bundle/Contents/Resources/English.lproj/InfoPlist.strings".text = ''
            NSHumanReadableCopyright = "Copyright 1997--2022 (c) Roland Kaufmann";
            "Programmer Dvorak" = "Programmer Dvorak";
          '';

          "Library/Keyboard Layouts/Programmer Dvorak.bundle/Contents/Resources/Programmer Dvorak.keylayout".source = keylayout;
        };
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
