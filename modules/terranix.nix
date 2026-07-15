# Generic Den <-> terranix wiring: any aspect can contribute a `terranix = {...};` class module
# (same shape as `nixos`/`darwin`/`homeManager`), scoped and merged per-host, turned into a
# `nix run .#<hostname>-tf` / `.#<hostname>-tf.plan` / `nix develop .#<hostname>-tf` Terraform
# workflow. See https://den.denful.dev/tutorials/terranix-demo/.
#
# A `terranix` field that's a FUNCTION requesting a den context arg (`host`, or a quirk like
# `virtual-host`) needs the `warnings-shim` below. Den's `wrapClassModule` attaches a
# collision-validator module (which sets a `warnings` output) to any such function;
# nixos/darwin/homeManager tolerate that fine (real NixOS-derived module types already have a
# `warnings` option), but terranix's own module type (upstream, not den) doesn't declare one, so
# `evalModules` throws "The option `warnings` does not exist" - not because of the value, just
# because nothing declared the option. `warnings-shim` declares it (default `[ ]`) so evaluation
# succeeds; terranix's own core (`core/default.nix`) then builds its final JSON by explicitly
# whitelisting only real Terraform keys (resource/variable/provider/etc.), so the shimmed
# `warnings` value never reaches config.tf.json regardless of its contents.
#
# The `terraform-secret` quirk: any aspect with a `terranix` field that needs a credential (a
# Terraform provider reading an API token from an env var - see dns.nix/meraki.nix) contributes
# the NAME of an age secret (declared on that same aspect's `secrets` field), same idea as
# `virtual-host`/`port-forward` (modules/aspects/my/virtual-host.nix,
# modules/aspects/my/port-forward.nix) - declared once per aspect, collected here rather than each
# aspect wiring its own separate `agenix -d | source` step by hand.
#
# The env var name is derived from the secret name (`env-var-for` below: kebab-case -> SCREAMING_SNAKE
# - e.g. `cloudflare-api-token` -> `CLOUDFLARE_API_TOKEN`), so name the secret to match whatever env
# var the provider actually reads - the provider's env var is the fixed, external constraint here,
# not the secret name.
#
# Collected per host into a single generated secret, `secrets/generated/<hostname>-tf.env.age`
# (create/update it like any other generated secret: `agenix generate -a && agenix rekey -a`) -
# `terraformWrapper.prefixText` below decrypts and sources it automatically before every `nix run
# .#<hostname>-tf*` invocation, so there's no manual per-secret `source <(agenix -d ...)` step to
# remember (or to add to) when a new aspect starts contributing a credential.
{
  den,
  inputs,
  lib,
  config,
  ...
}:
let
  warnings-shim = {
    options.warnings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  # kebab-case -> SCREAMING_SNAKE_CASE, e.g. `cloudflare-api-token` -> `CLOUDFLARE_API_TOKEN`.
  env-var-for = secret: lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] secret);

  # Collects `terraform-secret` quirk contributions for every host into that host's own
  # `"${host.name}-tf.env"` generated secret - lives outside any single aspect (like
  # virtual-host.nix/port-forward.nix's consumers) since it's shared plumbing, not owned by any one
  # service. `os` (not `nixos`) so this works identically whichever platform a future
  # terraform-contributing host runs - see modules/aspects/defaults.nix's `secrets` forwarding rule
  # for why `config.my.terraform-secrets` (set here) is visible from the `secrets` field below: both
  # land in the SAME per-host nixos/darwin evalModules pass. `secrets` itself can't request the
  # `terraform-secret` quirk directly - `age.secrets` is a flat `attrsOf submodule` with no
  # `warnings` option to shim (see the header comment above), so a field mixing a den-recognized
  # quirk with `secrets` (the self-reference used for `dependencies` below) breaks the same way
  # documented in modules/aspects/my/homepage.nix - hence stashing it through an option instead.
  terraform-secrets-aspect = { host, ... }: {
    os =
      {
        terraform-secret ? [ ],
        lib,
        ...
      }:
      {
        options.my.terraform-secrets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          internal = true;
          default = [ ];
        };

        config.my.terraform-secrets = terraform-secret;
      };

    secrets =
      {
        config,
        secrets,
        lib,
        ...
      }:
      lib.optionalAttrs (config.my.terraform-secrets != [ ]) {
        "${host.name}-tf.env".generator = {
          dependencies = lib.genAttrs config.my.terraform-secrets (name: secrets.${name});
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            lib.concatMapStrings (name: ''
              # %q (not a plain "%s") shell-quotes the decrypted value before it lands in the
              # generated env file - this file gets `source`d (see terraformWrapper.prefixText
              # below), so an unescaped value containing `$`, backticks, `\`, or `"` would be
              # reinterpreted by the shell instead of reproduced literally.
              printf '${env-var-for name}=%q\n' "$(${decrypt} ${lib.escapeShellArg deps.${name}.file})"
            '') config.my.terraform-secrets;
        };
      };
  };

  # Read from the file's own top-level `config` (closed over here, not re-requested) for the same
  # reason dns.nix's `perSystem` does the same for `config.flake.nixosConfigurations`: `config` is
  # ALSO the name flake-parts binds to each per-system module's own (different) result, so
  # requesting it again on the `perSystem` function below - needed there for the per-system
  # `config.agenix-rekey.package` - would silently shadow this outer one instead of erroring,
  # making `.flake.terranixModules` resolve to `{ }` and silently dropping every `<hostname>-tf`
  # package. Hoisting the lookup here, before that shadow exists, keeps both readable.
  terranix-modules = config.flake.terranixModules or { };
in
{
  flake-file.inputs.terranix = {
    url = "github:terranix/terranix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [ (inputs.terranix.flakeModule or { }) ];

  den = {
    classes.terranix = { };

    quirks.terraform-secret.description = "Names of age secrets a Terraform provider reads as env vars, decrypted into a per-host generated secret for `nix run .#<hostname>-tf`";

    policies.host-to-terranix = { host, ... }: [
      (den.lib.policy.instantiate {
        name = "${host.name}-tf";
        class = "terranix";
        instantiate = { modules, ... }: modules;
        # `-tf` suffix (rather than the bare host name) avoids colliding with the
        # `packages.<host>` each host already gets from Den's `nh` battery (quick-rebuild
        # shortcuts) - terranix's flake-module keys `packages.<system>.<key>` off this same
        # intoAttr name.
        intoAttr = [
          "terranixModules"
          "${host.name}-tf"
        ];
      })
    ];

    schema.host.includes = [
      den.policies.host-to-terranix
      terraform-secrets-aspect
    ];
  };

  # Guarded on `inputs ? terranix`: the first `nix run .#write-flake` pass after adding this
  # module runs before flake.nix/flake.lock actually have a `terranix` input, so the option this
  # sets (declared by terranix's own flakeModule, imported above) doesn't exist yet either.
  perSystem =
    { config, pkgs, ... }:
    lib.optionalAttrs (inputs ? terranix) {
      terranix.terranixConfigurations = lib.mapAttrs (
        key: modules:
        let
          # Every entry here is keyed `"${host.name}-tf"` (see `intoAttr` above), so stripping the
          # suffix recovers the host name without needing `host` itself in this scope.
          host-name = lib.removeSuffix "-tf" key;
          env-file = "secrets/generated/${host-name}-tf.env.age";
        in
        {
          modules = modules ++ [ warnings-shim ];
          terraformWrapper = {
            package = pkgs.opentofu;
            # No-ops for hosts with no `terraform-secret` contributions (nothing to generate, so
            # the file never exists). Both tools are called by their full store path (not left to
            # PATH) so this works even outside the dev shell.
            #
            # agenix-rekey's own CLI (`config.agenix-rekey.package`, built from its
            # nix/package.nix) is NOT plain agenix/ragenix - it has no `-d` flag. `view` is its
            # decrypt-to-stdout equivalent (apps/edit-view.nix). It internally `cd`s to the flake
            # root before resolving its FILE argument, so that argument must already be absolute -
            # `realpath ..` resolves it relative to the terraform workdir's parent, since
            # terranix's own template (`mkdir -p ${workdir}; cd ${workdir}`, applied before
            # prefixText runs) always puts us exactly one directory below wherever `nix run` was
            # invoked from.
            prefixText = ''
              env_file="$(${pkgs.coreutils}/bin/realpath ..)/${env-file}"
              if [ -f "$env_file" ]; then
                set -a
                # shellcheck disable=SC1090 # dynamic path is intentional - see env_file above
                source <(${config.agenix-rekey.package}/bin/agenix view "$env_file")
                set +a
              fi
            '';
          };
        }
      ) terranix-modules;
    };
}
