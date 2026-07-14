# Generic Den <-> terranix wiring: any aspect can contribute a `terranix = {...};` class module
# (same shape as `nixos`/`darwin`/`homeManager`), scoped and merged per-host, turned into a
# `nix run .#<hostname>-tf` / `.#<hostname>-tf.plan` / `nix develop .#<hostname>-tf` Terraform
# workflow. See https://den.denful.dev/tutorials/terranix-demo/.
#
# A `terranix` field that's a FUNCTION requesting a den context arg (`host`, or a quirk like
# `virtual-host`) needs the `warningsShim` below. Den's `wrapClassModule` attaches a
# collision-validator module (which sets a `warnings` output) to any such function;
# nixos/darwin/homeManager tolerate that fine (real NixOS-derived module types already have a
# `warnings` option), but terranix's own module type (upstream, not den) doesn't declare one, so
# `evalModules` throws "The option `warnings` does not exist" - not because of the value, just
# because nothing declared the option. `warningsShim` declares it (default `[ ]`) so evaluation
# succeeds; terranix's own core (`core/default.nix`) then builds its final JSON by explicitly
# whitelisting only real Terraform keys (resource/variable/provider/etc.), so the shimmed
# `warnings` value never reaches config.tf.json regardless of its contents.
{
  den,
  inputs,
  lib,
  config,
  ...
}:
let
  warningsShim = {
    options.warnings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
in
{
  flake-file.inputs.terranix = {
    url = "github:terranix/terranix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [ (inputs.terranix.flakeModule or { }) ];

  den.classes.terranix = { };

  den.policies.host-to-terranix = { host, ... }: [
    (den.lib.policy.instantiate {
      name = "${host.name}-tf";
      class = "terranix";
      instantiate = { modules, ... }: modules;
      # `-tf` suffix (rather than the bare host name) avoids colliding with the `packages.<host>`
      # each host already gets from Den's `nh` battery (quick-rebuild shortcuts) - terranix's
      # flake-module keys `packages.<system>.<key>` off this same intoAttr name.
      intoAttr = [
        "terranixModules"
        "${host.name}-tf"
      ];
    })
  ];

  den.schema.host.includes = [ den.policies.host-to-terranix ];

  # Guarded on `inputs ? terranix`: the first `nix run .#write-flake` pass after adding this
  # module runs before flake.nix/flake.lock actually have a `terranix` input, so the option this
  # sets (declared by terranix's own flakeModule, imported above) doesn't exist yet either.
  perSystem =
    { pkgs, ... }:
    lib.optionalAttrs (inputs ? terranix) {
      terranix.terranixConfigurations = lib.mapAttrs (_: modules: {
        modules = modules ++ [ warningsShim ];
        terraformWrapper.package = pkgs.opentofu;
      }) (config.flake.terranixModules or { });
    };
}
