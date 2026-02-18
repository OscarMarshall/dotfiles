# enables `nix run .#vm`. it is very useful to have a VM you can edit your config and launch the VM to test stuff
# instead of having to reboot each time.
{ inputs, ... }:
{

  den.aspects.my.includes = [ <my/vm/tui> ];

  perSystem =
    { pkgs, ... }:
    {
      packages.vm = pkgs.writeShellApplication {
        name = "vm";
        text = ''
          ${inputs.self.nixosConfigurations.harmony.config.system.build.vm}/bin/run-harmony-vm "$@"
        '';
      };
    };
}
