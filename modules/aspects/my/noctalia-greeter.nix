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

    # The greeter module reads this to know which account owns /var/lib/noctalia-greeter; greetd's
    # nixpkgs module creates the `greeter` user/group.
    services.greetd.settings.default_session.user = "greeter";
  };
}
