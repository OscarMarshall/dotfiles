{
  my.direnv = {
    homeManager = {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

    hmDarwin = { pkgs, ... }: {
      programs.direnv.package = pkgs.direnv.overrideAttrs (_: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });
    };
  };
}
