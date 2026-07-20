{ inputs, ... }:

{
  flake-file.inputs.pedantix = {
    url = "github:Swarsel/pedantix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [ (inputs.pedantix.flakeModules.default or { }) ];

  perSystem.treefmt.programs.pedantix = {
    enable = true;

    settings = {
      args = {
        first = [
          "config"
          "lib"
          "pkgs"
          "options"
          "modulesPath"
          "utils"
        ];

        last = [
          "<defaulted>"
          "..."
        ];

        sort = true;
      };

      attrs = {
        blank-lines = 1;
        blank-lines-mode = "multiline";

        first = [
          "flake-file"
          "includes"
          "imports"
          "options"
          "config"
          "enable"
          "package"
        ];

        last = [
          "meta"
          "provides"
        ];

        merge = true;
        sort = true;
      };

      formatter = "off";
      inherits.sort = true;
      lets.sort = true;

      overrides = [
        {
          path = "**.extraPackages";
          lists.sort = true;
        }
        {
          path = "flake-file.inputs.*";
          attrs.first = [ "url" ];
        }
        {
          path = "**.home.packages";
          lists.sort = true;
        }
        {
          path = "**.includes";
          lists.sort = true;
        }
        {
          path = "**.pedantix.settings.overrides";
          attrs.first = [ "path" ];
        }
        {
          path = "**.systemd.services.*";

          attrs.first = [
            "description"
            "wantedBy"
          ];
        }
      ];
    };
  };
}
