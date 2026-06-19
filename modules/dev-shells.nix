{ inputs, ... }: {
  imports = [ (inputs.agenix-rekey.flakeModule or { }) ];

  perSystem = { config, pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      inputsFrom = [ config.pre-commit.devShell ];
      nativeBuildInputs = [ config.agenix-rekey.package ];
      packages = [ pkgs.age-plugin-yubikey ];
    };
  };
}
