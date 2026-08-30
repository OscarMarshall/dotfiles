# Noctalia Greeter - a greetd greeter matching Noctalia's look. Replaces GDM as tensoon's login
# screen. NixOS-only (no home-manager module). The module enables greetd, sets the session command,
# and enables accounts-daemon for user avatars.
{ inputs, ... }: {
  flake-file.inputs.noctalia-greeter = {
    url = "github:noctalia-dev/noctalia-greeter";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.noctalia-greeter.nixos = { pkgs, ... }: {
    imports = [ inputs.noctalia-greeter.nixosModules.default ];

    programs.noctalia-greeter = {
      enable = true;
      # Default to the Umbriel session (Name= in umbriel.desktop). Run `noctalia-greeter sessions`
      # to confirm the exact name if the picker ever looks empty.
      greeter-args = "--session Umbriel";

      settings = {
        cursor = {
          path = "${pkgs.catppuccin-cursors.mochaDark}/share/icons";
          size = 24;
          theme = "catppuccin-mocha-dark-cursors";
        };

        idle.timeout = 300;
        keyboard.layout = "us";
      };
    };

    # Umbriel/Noctalia isn't GNOME, so nothing otherwise provides a secret-service (libsecret)
    # keyring. pass-cli, proton-pass-agent, and every other libsecret client stores credentials
    # there and fail hard without it ("Local encryption key not found -> force logout"). Enable
    # gnome-keyring and let pam_gnome_keyring create and unlock the login keyring with the sign-in
    # password. It goes on the `login` service, not `greetd`: nixpkgs only injects the keyring PAM
    # module where `unixAuth` is set, and greetd delegates both auth and session to `substack login`.
    # pass-cli (and other Rust `keyring`-crate clients on its keyutils backend) stashes its
    # local-DB key in the kernel session keyring with possessor-only permissions - so it is only
    # reachable by processes that *possess* that keyring. Without pam_keyinit the session falls
    # back to the shared _uid_ses.<uid>, where a key added by one `pass-cli` process isn't
    # searchable by the next and every call after the first dies with NoStorageAccess(AccessDenied).
    #
    # start-umbriel does `systemctl --user start umbriel.service`, so the whole graphical session
    # (compositor, Noctalia, terminals, and anything launched from them) lives under
    # user@<uid>.service, not the greetd session scope. That manager runs the `systemd-user` PAM
    # stack, so pam_keyinit has to go there to give the graphical tree its own anonymous session
    # keyring. `login` (which greetd substacks) covers plain TTY/console logins too. No `revoke` on
    # user@.service: it's long-lived and shared, so let the keyring die with the manager instead of
    # tearing it down mid-session. Ordered after pam_loginuid, before pam_systemd (order 12000).
    security.pam.services =
      let
        keyinit = extraArgs: {
          rules.session.keyinit = {
            args = [ "force" ] ++ extraArgs;
            control = "optional";
            modulePath = "${pkgs.pam}/lib/security/pam_keyinit.so";
            order = 10350;
          };
        };
      in
      {
        login = {
          enableGnomeKeyring = true;
        }
        // keyinit [ "revoke" ];

        systemd-user = keyinit [ ];
      };

    services = {
      gnome.gnome-keyring.enable = true;
      # The greeter module reads this to know which account owns /var/lib/noctalia-greeter; greetd's
      # nixpkgs module creates the `greeter` user/group.
      greetd.settings.default_session.user = "greeter";
    };
  };
}
